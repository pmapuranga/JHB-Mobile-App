<?php

namespace App\Console\Commands;

use App\Models\Sermon;
use App\Models\SermonSearch;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class ImportMobilePreload extends Command
{
    protected $signature = 'sermons:import-mobile
        {--books=../assets/preload/books.json}
        {--search=../assets/preload/search_index.json}';

    protected $description = 'Import the mobile preload JSON files into the admin MySQL sermon library.';

    public function handle(): int
    {
        $booksPath = base_path($this->option('books'));
        $searchPath = base_path($this->option('search'));

        if (! is_file($booksPath) || ! is_file($searchPath)) {
            $this->error('Could not find the mobile preload JSON files.');
            return self::FAILURE;
        }

        $books = json_decode((string) file_get_contents($booksPath), true, flags: JSON_THROW_ON_ERROR);
        $search = json_decode((string) file_get_contents($searchPath), true, flags: JSON_THROW_ON_ERROR);
        $entriesByBook = collect($search['entries'] ?? [])->groupBy('bookId');

        DB::transaction(function () use ($books, $entriesByBook) {
            foreach ($books['books'] ?? [] as $book) {
                $rawId = (string) ($book['id'] ?? Str::slug($book['title'] ?? Str::uuid()));
                $bookId = Str::startsWith($rawId, 'preloaded:') ? $rawId : "preloaded:{$rawId}";

                $sermon = Sermon::updateOrCreate(
                    ['book_id' => $bookId],
                    [
                        'code' => $book['idCode'] ?? null,
                        'title' => $book['title'] ?? 'Untitled Sermon',
                        'preacher' => $book['preacher'] ?? null,
                        'sermon_date' => $this->dateFromCode($book['idCode'] ?? null),
                        'place' => $book['location'] ?? 'JHB, Harare',
                        'language' => $book['language'] ?? 'en',
                        'category' => $book['category'] ?? 'sermon',
                        'audio_file' => $book['audio_file'] ?? $book['audio'] ?? null,
                        'duration_seconds' => 0,
                        'is_downloaded' => false,
                    ],
                );

                $sermon->paragraphs()->delete();
                SermonSearch::where('sermon_id', $sermon->sermon_id)->delete();

                $usedParagraphNumbers = [];
                $nextParagraphNumber = 1;

                foreach ($entriesByBook->get($bookId, collect()) as $entry) {
                    $paragraphNo = (int) ($entry['paragraph'] ?? $entry['sortOrder'] ?? $nextParagraphNumber);

                    if ($paragraphNo < 1 || isset($usedParagraphNumbers[$paragraphNo])) {
                        while (isset($usedParagraphNumbers[$nextParagraphNumber])) {
                            $nextParagraphNumber++;
                        }

                        $paragraphNo = $nextParagraphNumber;
                    }

                    $usedParagraphNumbers[$paragraphNo] = true;
                    $nextParagraphNumber = max($nextParagraphNumber, $paragraphNo + 1);

                    $paragraph = $sermon->paragraphs()->create([
                        'paragraph_no' => $paragraphNo,
                        'text' => $entry['text'] ?? '',
                        'start_time_ms' => $entry['startMs'] ?? null,
                        'end_time_ms' => $entry['endMs'] ?? null,
                    ]);

                    SermonSearch::create([
                        'sermon_id' => $sermon->sermon_id,
                        'paragraph_id' => $paragraph->paragraph_id,
                        'title' => $sermon->title,
                        'text' => $paragraph->text,
                    ]);
                }
            }
        });

        $this->info('Imported '.Sermon::count().' sermons and '.DB::table('sermon_paragraphs')->count().' paragraphs.');
        return self::SUCCESS;
    }

    private function dateFromCode(?string $code): ?string
    {
        if (! $code || ! preg_match('/^(\d{2})-(\d{2})(\d{2})/', $code, $matches)) {
            return null;
        }

        $year = (int) $matches[1];
        $century = $year >= 40 ? 1900 : 2000;

        return sprintf('%04d-%02d-%02d', $century + $year, $matches[2], $matches[3]);
    }
}
