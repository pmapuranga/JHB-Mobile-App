<?php

namespace App\Console\Commands;

use App\Models\Sermon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Str;
use PDO;
use Throwable;

class ExportMobileSqlite extends Command
{
    protected $signature = 'sermons:export-mobile
        {--output=../assets/preload/sermon_library.sqlite}';

    protected $description = 'Export admin MySQL sermon data into a mobile SQLite database.';

    public function handle(): int
    {
        $output = dirname(base_path($this->option('output'))).DIRECTORY_SEPARATOR.basename($this->option('output'));
        File::ensureDirectoryExists(dirname($output));

        $tempOutput = $output.'.tmp';
        if (is_file($tempOutput) && ! @unlink($tempOutput)) {
            $this->error("Could not remove old temporary export file: {$tempOutput}");

            return self::FAILURE;
        }

        try {
            $pdo = new PDO('sqlite:'.$tempOutput);
            $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            $this->createSchema($pdo);

            $sermons = Sermon::with('paragraphs')->orderBy('code')->get();
            $insertSermon = $pdo->prepare('
                INSERT INTO sermons
                (sermon_id, code, title, preacher, sermon_date, place, language, category, audio_file, duration_seconds, is_downloaded, book_id)
                VALUES
                (:sermon_id, :code, :title, :preacher, :sermon_date, :place, :language, :category, :audio_file, :duration_seconds, :is_downloaded, :book_id)
            ');
            $insertParagraph = $pdo->prepare('
                INSERT INTO sermon_paragraphs
                (paragraph_id, sermon_id, paragraph_no, text, start_time_ms, end_time_ms)
                VALUES
                (:paragraph_id, :sermon_id, :paragraph_no, :text, :start_time_ms, :end_time_ms)
            ');
            $insertSearch = $pdo->prepare('
                INSERT INTO sermon_search (title, text, sermon_id, paragraph_id)
                VALUES (:title, :text, :sermon_id, :paragraph_id)
            ');

            $pdo->beginTransaction();
            foreach ($sermons as $sermon) {
                $mobileBookId = $this->mobileBookId($sermon);
                $audioAsset = $this->mobileAudioAsset($sermon);
                $insertSermon->execute([
                    'sermon_id' => $sermon->sermon_id,
                    'code' => $sermon->code,
                    'title' => $sermon->title,
                    'preacher' => $sermon->preacher,
                    'sermon_date' => optional($sermon->sermon_date)->format('Y-m-d'),
                    'place' => $sermon->place,
                    'language' => $sermon->language,
                    'category' => $sermon->category,
                    'audio_file' => $audioAsset,
                    'duration_seconds' => $sermon->duration_seconds,
                    'is_downloaded' => $sermon->is_downloaded ? 1 : 0,
                    'book_id' => 'preloaded:'.$mobileBookId,
                ]);

                foreach ($sermon->paragraphs as $paragraph) {
                    $insertParagraph->execute([
                        'paragraph_id' => $paragraph->paragraph_id,
                        'sermon_id' => $paragraph->sermon_id,
                        'paragraph_no' => $paragraph->paragraph_no,
                        'text' => $paragraph->text,
                        'start_time_ms' => $paragraph->start_time_ms,
                        'end_time_ms' => $paragraph->end_time_ms,
                    ]);
                    $insertSearch->execute([
                        'title' => $sermon->title,
                        'text' => $paragraph->text,
                        'sermon_id' => $sermon->sermon_id,
                        'paragraph_id' => $paragraph->paragraph_id,
                    ]);
                }
            }
            $pdo->commit();
            $insertSermon = null;
            $insertParagraph = null;
            $insertSearch = null;
            $pdo = null;

            if (is_file($output) && ! @unlink($output)) {
                @unlink($tempOutput);
                $this->error("Could not replace {$output}. Close any app using the SQLite package and try again.");

                return self::FAILURE;
            }

            if (! @rename($tempOutput, $output)) {
                @unlink($tempOutput);
                $this->error("Could not move the new export into place: {$output}");

                return self::FAILURE;
            }

            $this->writeLegacyJsonPackage($sermons);
        } catch (Throwable $exception) {
            if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) {
                $pdo->rollBack();
            }

            $pdo = null;
            @unlink($tempOutput);

            $this->error('Mobile export failed: '.$exception->getMessage());

            return self::FAILURE;
        }

        $this->info("Exported {$sermons->count()} sermons to {$output}");
        return self::SUCCESS;
    }

    private function writeLegacyJsonPackage($sermons): void
    {
        $preloadDir = base_path('../assets/preload');
        File::ensureDirectoryExists($preloadDir);

        $books = [];
        $entries = [];

        foreach ($sermons as $sermon) {
            $bookId = $this->mobileBookId($sermon);
            $audioAsset = $this->mobileAudioAsset($sermon);
            $books[] = [
                'id' => $bookId,
                'title' => $sermon->title,
                'idCode' => $sermon->code ?? '',
                'location' => $sermon->place ?: 'JHB, Harare',
                'duration' => $this->formatDuration((int) $sermon->duration_seconds),
                'audio' => $audioAsset,
                'category' => $sermon->category ?: 'sermon',
                'language' => $sermon->language ?: 'en',
            ];

            foreach ($sermon->paragraphs as $paragraph) {
                $entries[] = [
                    'bookId' => 'preloaded:'.$bookId,
                    'title' => $sermon->title,
                    'idCode' => $sermon->code ?? '',
                    'location' => $sermon->place ?: 'JHB, Harare',
                    'paragraph' => $paragraph->paragraph_no,
                    'sortOrder' => $paragraph->paragraph_no,
                    'text' => $paragraph->text,
                    'startMs' => $paragraph->start_time_ms,
                    'endMs' => $paragraph->end_time_ms,
                ];
            }
        }

        $version = now()->timestamp;
        File::put($preloadDir.'/books.json', json_encode([
            'version' => $version,
            'books' => $books,
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));

        File::put($preloadDir.'/search_index.json', json_encode([
            'version' => $version,
            'entries' => $entries,
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
    }

    private function mobileBookId(Sermon $sermon): string
    {
        $bookId = (string) ($sermon->book_id ?: '');
        $bookId = Str::after($bookId, 'preloaded:');
        $bookId = Str::after($bookId, 'admin:');

        if ($bookId !== '') {
            return Str::slug($bookId);
        }

        return Str::slug(trim(($sermon->code ?? '').' '.$sermon->title));
    }

    private function mobileAudioAsset(Sermon $sermon): string
    {
        $audioFile = trim((string) $sermon->audio_file);
        if ($audioFile === '') {
            return '';
        }

        if (Str::startsWith($audioFile, 'assets/preload/audios/')) {
            return $audioFile;
        }

        $filename = basename($audioFile);
        $targetDir = base_path('../assets/preload/audios');
        $targetPath = $targetDir.DIRECTORY_SEPARATOR.$filename;
        File::ensureDirectoryExists($targetDir);

        $candidates = [
            storage_path('app/public/audios/'.$audioFile),
            storage_path('app/public/'.$audioFile),
            base_path('../assets/preload/audios/'.$audioFile),
            base_path('../assets/preload/audios/'.$filename),
        ];

        foreach ($candidates as $candidate) {
            if (is_file($candidate)) {
                if (realpath($candidate) !== realpath($targetPath)) {
                    File::copy($candidate, $targetPath);
                }

                return 'assets/preload/audios/'.$filename;
            }
        }

        return $audioFile;
    }

    private function formatDuration(int $seconds): string
    {
        if ($seconds <= 0) {
            return 'TIME: 0:00';
        }

        $hours = intdiv($seconds, 3600);
        $minutes = intdiv($seconds % 3600, 60);
        $remainingSeconds = $seconds % 60;

        if ($hours > 0) {
            return sprintf('TIME: %d:%02d:%02d', $hours, $minutes, $remainingSeconds);
        }

        return sprintf('TIME: %d:%02d', $minutes, $remainingSeconds);
    }

    private function createSchema(PDO $pdo): void
    {
        $pdo->exec('CREATE TABLE sermons (
            sermon_id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT,
            title TEXT NOT NULL,
            preacher TEXT,
            sermon_date TEXT,
            place TEXT,
            language TEXT DEFAULT "en",
            category TEXT,
            audio_file TEXT,
            duration_seconds INTEGER DEFAULT 0,
            is_downloaded INTEGER DEFAULT 0,
            book_id TEXT UNIQUE
        )');
        $pdo->exec('CREATE TABLE sermon_paragraphs (
            paragraph_id INTEGER PRIMARY KEY AUTOINCREMENT,
            sermon_id INTEGER NOT NULL,
            paragraph_no INTEGER NOT NULL,
            text TEXT NOT NULL,
            start_time_ms INTEGER,
            end_time_ms INTEGER
        )');
        $pdo->exec('CREATE TABLE sermon_search (
            title TEXT,
            text TEXT,
            sermon_id INTEGER,
            paragraph_id INTEGER
        )');
        $pdo->exec('CREATE TABLE downloads (
            download_id INTEGER PRIMARY KEY AUTOINCREMENT,
            sermon_id INTEGER,
            audio_url TEXT,
            local_path TEXT,
            file_format TEXT DEFAULT "opus",
            downloaded_at TEXT
        )');
        $pdo->exec('CREATE TABLE bookmarks (
            bookmark_id INTEGER PRIMARY KEY AUTOINCREMENT,
            sermon_id INTEGER,
            paragraph_id INTEGER,
            note TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )');
        $pdo->exec('CREATE TABLE highlights (
            highlight_id INTEGER PRIMARY KEY AUTOINCREMENT,
            sermon_id INTEGER,
            paragraph_id INTEGER,
            start_offset INTEGER,
            end_offset INTEGER,
            color TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )');
    }
}
