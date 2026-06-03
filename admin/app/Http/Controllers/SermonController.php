<?php

namespace App\Http\Controllers;

use App\Models\Sermon;
use App\Models\SermonParagraph;
use App\Models\SermonSearch;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\BinaryFileResponse;
use Illuminate\View\View;

class SermonController extends Controller
{
    public function index(Request $request): View
    {
        $groupBy = $request->query('group_by', 'none');
        $allowedGroups = ['none', 'year', 'month', 'place', 'preacher', 'category'];
        if (! in_array($groupBy, $allowedGroups, true)) {
            $groupBy = 'none';
        }

        $query = Sermon::query()
            ->withCount('paragraphs')
            ->orderByDesc('sermon_date')
            ->orderByDesc('code');

        if ($search = trim((string) $request->query('q'))) {
            $query->where(function ($builder) use ($search) {
                $builder->where('title', 'like', "%{$search}%")
                    ->orWhere('code', 'like', "%{$search}%")
                    ->orWhere('place', 'like', "%{$search}%");
            });
        }

        if ($groupBy !== 'none') {
            $sermons = $query->get();

            return view('sermons.index', [
                'sermons' => null,
                'groupedSermons' => $this->groupSermons($sermons, $groupBy),
                'search' => $search ?? '',
                'groupBy' => $groupBy,
            ]);
        }

        return view('sermons.index', [
            'sermons' => $query->paginate(25)->withQueryString(),
            'groupedSermons' => null,
            'search' => $search ?? '',
            'groupBy' => $groupBy,
        ]);
    }

    public function show(Sermon $sermon): View
    {
        return view('sermons.show', [
            'sermon' => $sermon->load('paragraphs'),
            'audioUrl' => $this->audioUrl($sermon),
        ]);
    }

    public function create(): View
    {
        return view('sermons.create');
    }

    public function store(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'code' => ['nullable', 'string', 'max:255'],
            'title' => ['required', 'string', 'max:255'],
            'preacher' => ['nullable', 'string', 'max:255'],
            'sermon_date' => ['nullable', 'date'],
            'place' => ['required', 'string', 'max:255'],
            'language' => ['required', 'string', 'max:12'],
            'category' => ['nullable', 'string', 'max:255'],
            'duration_seconds' => ['nullable', 'integer', 'min:0'],
            'is_downloaded' => ['nullable', 'boolean'],
            'transcript_text' => ['nullable', 'string'],
            'transcript_file' => ['nullable', 'file', 'mimetypes:text/plain,text/markdown,application/octet-stream', 'max:10240'],
            'audio_upload' => ['nullable', 'file', 'mimes:mp3,wav,ogg,opus,m4a,mp4,aac,flac', 'max:524288'],
        ]);

        $transcript = (string) ($validated['transcript_text'] ?? '');
        if ($request->hasFile('transcript_file')) {
            $transcript = (string) file_get_contents($request->file('transcript_file')->getRealPath());
        }

        $validated['is_downloaded'] = $request->boolean('is_downloaded');
        $validated['duration_seconds'] = $validated['duration_seconds'] ?? 0;
        $validated['book_id'] = 'admin:'.Str::slug($validated['code'] ?: $validated['title']).'-'.Str::lower(Str::random(8));

        if ($request->hasFile('audio_upload')) {
            $validated['audio_file'] = $this->storeAudio($request, $validated['code'] ?: $validated['title']);
        }

        unset($validated['transcript_text'], $validated['transcript_file'], $validated['audio_upload']);

        $sermon = DB::transaction(function () use ($validated, $transcript) {
            $sermon = Sermon::create($validated);

            foreach ($this->splitTranscript($transcript) as $index => $text) {
                $paragraph = $sermon->paragraphs()->create([
                    'paragraph_no' => $index + 1,
                    'text' => $text,
                ]);

                SermonSearch::create([
                    'sermon_id' => $sermon->sermon_id,
                    'paragraph_id' => $paragraph->paragraph_id,
                    'title' => $sermon->title,
                    'text' => $paragraph->text,
                ]);
            }

            return $sermon;
        });

        return redirect()
            ->route('sermons.edit', $sermon)
            ->with('status', 'Sermon uploaded. Add timestamps and review the mobile export fields.');
    }

    public function edit(Sermon $sermon): View
    {
        return view('sermons.edit', [
            'sermon' => $sermon->load('paragraphs'),
            'audioUrl' => $this->audioUrl($sermon),
        ]);
    }

    public function update(Request $request, Sermon $sermon): RedirectResponse
    {
        $validated = $request->validate([
            'code' => ['nullable', 'string', 'max:255'],
            'title' => ['required', 'string', 'max:255'],
            'preacher' => ['nullable', 'string', 'max:255'],
            'sermon_date' => ['nullable', 'date'],
            'place' => ['required', 'string', 'max:255'],
            'language' => ['required', 'string', 'max:12'],
            'category' => ['nullable', 'string', 'max:255'],
            'audio_file' => ['nullable', 'string', 'max:255'],
            'audio_upload' => ['nullable', 'file', 'mimes:mp3,wav,ogg,opus,m4a,mp4,aac,flac', 'max:524288'],
            'duration_seconds' => ['nullable', 'integer', 'min:0'],
            'is_downloaded' => ['nullable', 'boolean'],
            'new_paragraphs' => ['nullable', 'string'],
        ]);

        $validated['is_downloaded'] = $request->boolean('is_downloaded');
        if ($request->hasFile('audio_upload')) {
            $validated['audio_file'] = $this->storeAudio($request, $validated['code'] ?: $validated['title']);
        }

        $newParagraphs = (string) ($validated['new_paragraphs'] ?? '');

        unset($validated['audio_upload'], $validated['new_paragraphs']);
        $sermon->update($validated);

        foreach ($request->input('paragraphs', []) as $paragraphId => $data) {
            $paragraph = $sermon->paragraphs()
                ->whereKey($paragraphId)
                ->first();
            if (! $paragraph) {
                continue;
            }

            $paragraph->update([
                'text' => $data['text'] ?? '',
                'start_time_ms' => $this->parseTimestampMs($data['start_time'] ?? null),
                'end_time_ms' => $this->parseTimestampMs($data['end_time'] ?? null),
            ]);

            SermonSearch::updateOrCreate(
                ['paragraph_id' => $paragraph->paragraph_id],
                [
                    'sermon_id' => $sermon->sermon_id,
                    'title' => $sermon->title,
                    'text' => $paragraph->text,
                ],
            );
        }

        $added = $this->appendParagraphs($sermon, $newParagraphs);

        return redirect()
            ->route('sermons.edit', $sermon)
            ->with('status', $added > 0 ? "Sermon updated. Added {$added} paragraphs." : 'Sermon updated.');
    }

    public function audio(Sermon $sermon): BinaryFileResponse
    {
        $path = $this->audioPath($sermon);

        abort_unless($path, 404);

        return response()->file($path);
    }

    private function storeAudio(Request $request, string $name): string
    {
        $file = $request->file('audio_upload');
        $filename = Str::slug(pathinfo($name, PATHINFO_FILENAME) ?: 'sermon').'-'.Str::random(8).'.'.$file->getClientOriginalExtension();
        $file->storeAs('audios', $filename, 'public');

        return $filename;
    }

    /**
     * @return array<int, string>
     */
    private function splitTranscript(string $transcript): array
    {
        $transcript = trim(str_replace(["\r\n", "\r"], "\n", $transcript));

        if ($transcript === '') {
            return [];
        }

        $paragraphs = preg_split("/\n\s*\n/", $transcript) ?: [];
        if (count($paragraphs) === 1) {
            $paragraphs = preg_split("/\n+/", $transcript) ?: [];
        }

        return array_values(array_filter(array_map(
            fn (string $text): string => trim(preg_replace('/\s+/', ' ', $text) ?? $text),
            $paragraphs,
        )));
    }

    private function parseTimestampMs(?string $value): ?int
    {
        $value = trim((string) $value);

        if ($value === '') {
            return null;
        }

        if (is_numeric($value)) {
            return max(0, (int) $value);
        }

        $parts = array_map('trim', explode(':', $value));
        if (count($parts) < 2 || count($parts) > 3) {
            return null;
        }

        $seconds = (float) array_pop($parts);
        $minutes = (int) array_pop($parts);
        $hours = count($parts) ? (int) array_pop($parts) : 0;

        return max(0, (int) round((($hours * 3600) + ($minutes * 60) + $seconds) * 1000));
    }

    private function appendParagraphs(Sermon $sermon, string $transcript): int
    {
        $paragraphs = $this->splitTranscript($transcript);
        if ($paragraphs === []) {
            return 0;
        }

        $nextParagraphNo = ((int) $sermon->paragraphs()->max('paragraph_no')) + 1;
        foreach ($paragraphs as $index => $text) {
            $paragraph = $sermon->paragraphs()->create([
                'paragraph_no' => $nextParagraphNo + $index,
                'text' => $text,
            ]);

            SermonSearch::create([
                'sermon_id' => $sermon->sermon_id,
                'paragraph_id' => $paragraph->paragraph_id,
                'title' => $sermon->title,
                'text' => $paragraph->text,
            ]);
        }

        return count($paragraphs);
    }

    private function audioUrl(Sermon $sermon): ?string
    {
        return $this->audioPath($sermon) ? route('sermons.audio', $sermon) : null;
    }

    private function audioPath(Sermon $sermon): ?string
    {
        if (! $sermon->audio_file) {
            return null;
        }

        $candidates = [
            storage_path('app/public/audios/'.$sermon->audio_file),
            base_path('../assets/preload/audios/'.$sermon->audio_file),
            base_path('../assets/preload/audios/'.basename($sermon->audio_file)),
        ];

        foreach ($candidates as $path) {
            if (is_file($path)) {
                return $path;
            }
        }

        if (Str::startsWith($sermon->audio_file, 'audios/') && Storage::disk('public')->exists($sermon->audio_file)) {
            return Storage::disk('public')->path($sermon->audio_file);
        }

        return null;
    }

    private function groupSermons($sermons, string $groupBy)
    {
        return $sermons
            ->groupBy(function (Sermon $sermon) use ($groupBy): string {
                return match ($groupBy) {
                    'year' => $sermon->sermon_date ? $sermon->sermon_date->format('Y') : 'Date not set',
                    'month' => $sermon->sermon_date ? $sermon->sermon_date->format('F Y') : 'Date not set',
                    'place' => $sermon->place ?: 'Place not set',
                    'preacher' => $sermon->preacher ?: 'Preacher not set',
                    'category' => $sermon->category ?: 'Category not set',
                    default => 'All sermons',
                };
            })
            ->sortKeysDesc();
    }
}
