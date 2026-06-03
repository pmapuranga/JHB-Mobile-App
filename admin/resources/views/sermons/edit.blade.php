@extends('layouts.app')

@php
    $formatMs = function ($value) {
        if ($value === null) {
            return '';
        }

        $totalMs = (int) $value;
        $hours = intdiv($totalMs, 3600000);
        $totalMs %= 3600000;
        $minutes = intdiv($totalMs, 60000);
        $totalMs %= 60000;
        $seconds = intdiv($totalMs, 1000);
        $ms = $totalMs % 1000;

        return $hours > 0
            ? sprintf('%d:%02d:%02d.%03d', $hours, $minutes, $seconds, $ms)
            : sprintf('%02d:%02d.%03d', $minutes, $seconds, $ms);
    };
@endphp

@php
    $hasParagraphTimings = $sermon->paragraphs->contains(
        fn ($paragraph) => $paragraph->start_time_ms !== null || $paragraph->end_time_ms !== null,
    );
@endphp

@section('content')
    <div class="toolbar">
        <div>
            <p class="page-kicker">Edit</p>
            <h1 style="margin:0">Edit Sermon</h1>
            <p class="muted" style="margin:6px 0 0">{{ $sermon->code }} &middot; {{ $sermon->title }}</p>
        </div>
        <a class="button secondary" href="{{ route('sermons.show', $sermon) }}">Cancel</a>
    </div>

    <form method="post" action="{{ route('sermons.update', $sermon) }}" enctype="multipart/form-data">
        @csrf
        @method('put')

        <div class="panel">
            <h2 style="margin-top:0">Mobile Metadata</h2>
            <div class="grid two">
                <div>
                    <label for="code">Code</label>
                    <input id="code" name="code" value="{{ old('code', $sermon->code) }}">
                    @error('code') <div class="danger">{{ $message }}</div> @enderror
                </div>
                <div>
                    <label for="title">Title</label>
                    <input id="title" name="title" value="{{ old('title', $sermon->title) }}" required>
                    @error('title') <div class="danger">{{ $message }}</div> @enderror
                </div>
                <div>
                    <label for="preacher">Preacher</label>
                    <input id="preacher" name="preacher" value="{{ old('preacher', $sermon->preacher) }}">
                </div>
                <div>
                    <label for="sermon_date">Sermon Date</label>
                    <input id="sermon_date" type="date" name="sermon_date" value="{{ old('sermon_date', optional($sermon->sermon_date)->format('Y-m-d')) }}">
                </div>
                <div>
                    <label for="place">Place</label>
                    <input id="place" name="place" value="{{ old('place', $sermon->place) }}" required>
                </div>
                <div>
                    <label for="language">Language</label>
                    <input id="language" name="language" value="{{ old('language', $sermon->language) }}" required>
                </div>
                <div>
                    <label for="category">Category</label>
                    <input id="category" name="category" value="{{ old('category', $sermon->category) }}">
                </div>
                <div>
                    <label for="audio_file">Audio File</label>
                    <input id="audio_file" name="audio_file" value="{{ old('audio_file', $sermon->audio_file) }}" placeholder="09-0602.opus">
                </div>
                <div>
                    <label for="audio_upload">Replace Audio</label>
                    <input id="audio_upload" type="file" name="audio_upload" accept=".mp3,.wav,.ogg,.opus,.m4a,.mp4,audio/*">
                    @error('audio_upload') <div class="danger">{{ $message }}</div> @enderror
                </div>
                <div>
                    <label for="duration_seconds">Duration Seconds</label>
                    <input id="duration_seconds" type="number" min="0" name="duration_seconds" value="{{ old('duration_seconds', $sermon->duration_seconds) }}">
                </div>
                <label style="display:flex; align-items:center; gap:8px">
                    <input type="checkbox" name="is_downloaded" value="1" @checked(old('is_downloaded', $sermon->is_downloaded)) style="width:auto">
                    Available Offline
                </label>
            </div>
        </div>

        <div class="panel" style="margin-top:18px">
            <div class="sticky-audio-rail">
                <h2>Timestamp Editor</h2>
            @if ($audioUrl)
                <div class="audio-transport" aria-label="Audio playback controls">
                    <div class="transport-buttons">
                        <button class="subtle transport-icon" type="button" data-skip="-10" title="Back 10 seconds" aria-label="Back 10 seconds">-10</button>
                        <button class="transport-icon primary" type="button" data-audio-play title="Play" aria-label="Play">▶</button>
                        <button class="subtle transport-icon" type="button" data-audio-pause title="Pause" aria-label="Pause">⏸</button>
                        <button class="transport-icon secondary-dark" type="button" data-audio-stop title="Stop" aria-label="Stop">■</button>
                        <button class="subtle transport-icon" type="button" data-skip="10" title="Forward 10 seconds" aria-label="Forward 10 seconds">+10</button>
                    </div>
                    <div class="progress-wrap">
                        <input class="audio-progress" type="range" min="0" max="0" value="0" step="0.01" data-audio-progress aria-label="Audio position">
                    </div>
                    <div class="time-readout"><span data-current-time>00:00</span> / <span data-duration>00:00</span></div>
                    <label class="speed-control" for="audio-speed">
                        Speed
                        <select id="audio-speed" data-audio-speed>
                            <option value="0.75">0.75x</option>
                            <option value="1" selected>1x</option>
                            <option value="1.25">1.25x</option>
                            <option value="1.5">1.5x</option>
                            <option value="1.75">1.75x</option>
                            <option value="2">2x</option>
                        </select>
                    </label>
                </div>
                <div class="shortcut-hints">
                    <span><kbd>Space</kbd> play/pause</span>
                    <span><kbd>S</kbd> stop</span>
                    <span><kbd>←</kbd>/<kbd>→</kbd> skip 10s</span>
                    <span><kbd>[</kbd>/<kbd>]</kbd> speed</span>
                    <span><kbd>A</kbd> start</span>
                    <span><kbd>D</kbd> end</span>
                </div>
                @unless ($hasParagraphTimings)
                    <p class="muted" style="margin:6px 0 0; font-size:11px">No paragraph timestamps yet. Highlighting starts after you add start/end times, or while you are setting them in this editor.</p>
                @endunless
                <audio id="sermon-audio" preload="metadata" src="{{ $audioUrl }}"></audio>
            @else
                <p class="muted" style="margin:0">Upload or reference an audio file to enable playback while editing timestamps.</p>
            @endif
        </div>

            <div class="transcript-add">
                <h3>Add Paragraphs</h3>
                <p class="muted" style="margin-top:-4px">Paste one paragraph per line, or separate longer paragraphs with blank lines. New entries are appended after the current transcript.</p>
                <label for="new_paragraphs">New Paragraph Text</label>
                <textarea id="new_paragraphs" name="new_paragraphs" style="min-height:160px" placeholder="Paragraph 1&#10;&#10;Paragraph 2">{{ old('new_paragraphs') }}</textarea>
                @error('new_paragraphs') <div class="danger">{{ $message }}</div> @enderror
            </div>

            @foreach ($sermon->paragraphs as $paragraph)
                <div class="paragraph" data-paragraph-no="{{ $paragraph->paragraph_no }}">
                    <h3 style="margin-top:0">Paragraph {{ $paragraph->paragraph_no }}</h3>
                    <div class="grid two">
                        <div class="timestamp-tools">
                            <div>
                                <label>Start Time</label>
                                <input data-time-input name="paragraphs[{{ $paragraph->paragraph_id }}][start_time]" value="{{ old("paragraphs.{$paragraph->paragraph_id}.start_time", $formatMs($paragraph->start_time_ms)) }}" placeholder="00:00.000">
                            </div>
                            <button class="subtle" type="button" data-set-current>Use Current</button>
                            <button class="subtle" type="button" data-jump-to>Jump</button>
                        </div>
                        <div class="timestamp-tools">
                            <div>
                                <label>End Time</label>
                                <input data-time-input name="paragraphs[{{ $paragraph->paragraph_id }}][end_time]" value="{{ old("paragraphs.{$paragraph->paragraph_id}.end_time", $formatMs($paragraph->end_time_ms)) }}" placeholder="00:00.000">
                            </div>
                            <button class="subtle" type="button" data-set-current>Use Current</button>
                            <button class="subtle" type="button" data-jump-to>Jump</button>
                        </div>
                    </div>
                    <div style="margin-top:12px">
                        <label>Text</label>
                        <textarea name="paragraphs[{{ $paragraph->paragraph_id }}][text]">{{ old("paragraphs.{$paragraph->paragraph_id}.text", $paragraph->text) }}</textarea>
                    </div>
                </div>
            @endforeach
        </div>

        <div style="margin-top:18px">
            <button type="submit">Save Changes</button>
        </div>
    </form>

    <form method="post" action="{{ route('exports.mobile') }}" style="margin-top:10px">
        @csrf
        <button class="secondary" type="submit">Export Mobile Package</button>
    </form>

    <script>
        const audio = document.getElementById('sermon-audio');
        const formatTime = (seconds) => {
            const totalMs = Math.max(0, Math.round(seconds * 1000));
            const hours = Math.floor(totalMs / 3600000);
            const minutes = Math.floor((totalMs % 3600000) / 60000);
            const secs = Math.floor((totalMs % 60000) / 1000);
            const ms = totalMs % 1000;
            const pad = (value, width = 2) => String(value).padStart(width, '0');

            return hours > 0
                ? `${hours}:${pad(minutes)}:${pad(secs)}.${pad(ms, 3)}`
                : `${pad(minutes)}:${pad(secs)}.${pad(ms, 3)}`;
        };
        const parseTime = (value) => {
            if (!value) {
                return null;
            }

            if (!Number.isNaN(Number(value))) {
                return Number(value) / 1000;
            }

            const parts = value.split(':').map((part) => part.trim());
            if (parts.length < 2 || parts.length > 3) {
                return null;
            }

            const seconds = Number(parts.pop());
            const minutes = Number(parts.pop());
            const hours = parts.length ? Number(parts.pop()) : 0;

            if ([seconds, minutes, hours].some((part) => Number.isNaN(part))) {
                return null;
            }

            return hours * 3600 + minutes * 60 + seconds;
        };
        const formatClock = (seconds) => {
            if (!Number.isFinite(seconds) || seconds < 0) {
                return '00:00';
            }

            const totalSeconds = Math.floor(seconds);
            const hours = Math.floor(totalSeconds / 3600);
            const minutes = Math.floor((totalSeconds % 3600) / 60);
            const secs = totalSeconds % 60;
            const pad = (value) => String(value).padStart(2, '0');

            return hours > 0
                ? `${hours}:${pad(minutes)}:${pad(secs)}`
                : `${pad(minutes)}:${pad(secs)}`;
        };
        const progress = document.querySelector('[data-audio-progress]');
        const currentTime = document.querySelector('[data-current-time]');
        const duration = document.querySelector('[data-duration]');
        const speedSelect = document.querySelector('[data-audio-speed]');
        const paragraphRows = Array.from(document.querySelectorAll('.paragraph'));
        const syncProgress = () => {
            if (!audio || !progress) {
                return;
            }

            progress.max = Number.isFinite(audio.duration) ? audio.duration : 0;
            progress.value = audio.currentTime || 0;
            if (currentTime) {
                currentTime.textContent = formatClock(audio.currentTime);
            }
            if (duration) {
                duration.textContent = formatClock(audio.duration);
            }
            highlightCurrentParagraph();
        };
        const getParagraphRange = (paragraph, index) => {
            const startInput = paragraph.querySelector('[name$="[start_time]"]');
            const endInput = paragraph.querySelector('[name$="[end_time]"]');
            const start = parseTime(startInput?.value);
            let end = parseTime(endInput?.value);

            if (start === null) {
                return null;
            }

            if (end === null) {
                const nextTimedParagraph = paragraphRows.slice(index + 1).find((row) => {
                    const nextStart = parseTime(row.querySelector('[name$="[start_time]"]')?.value);

                    return nextStart !== null && nextStart > start;
                });
                end = nextTimedParagraph
                    ? parseTime(nextTimedParagraph.querySelector('[name$="[start_time]"]')?.value)
                    : Infinity;
            }

            if (end <= start) {
                return null;
            }

            return { start, end };
        };
        const highlightCurrentParagraph = () => {
            if (!audio || paragraphRows.length === 0) {
                return;
            }

            const current = audio.currentTime;
            let activeParagraph = null;
            paragraphRows.forEach((paragraph, index) => {
                const range = getParagraphRange(paragraph, index);
                const isActive = range !== null && current >= range.start && current < range.end;
                paragraph.classList.toggle('is-current', isActive);
                if (isActive) {
                    activeParagraph = paragraph;
                }
            });

            return activeParagraph;
        };

        audio?.addEventListener('loadedmetadata', syncProgress);
        audio?.addEventListener('timeupdate', syncProgress);
        audio?.addEventListener('durationchange', syncProgress);
        progress?.addEventListener('input', (event) => {
            if (!audio) {
                return;
            }

            audio.currentTime = Number(event.target.value);
            syncProgress();
        });
        document.querySelectorAll('[data-time-input]').forEach((input) => {
            input.addEventListener('input', highlightCurrentParagraph);
        });
        syncProgress();

        document.querySelectorAll('[data-set-current]').forEach((button) => {
            button.addEventListener('click', () => {
                if (!audio) {
                    return;
                }

                button.closest('.timestamp-tools').querySelector('[data-time-input]').value = formatTime(audio.currentTime);
            });
        });

        document.querySelectorAll('[data-jump-to]').forEach((button) => {
            button.addEventListener('click', () => {
                if (!audio) {
                    return;
                }

                const seconds = parseTime(button.closest('.timestamp-tools').querySelector('[data-time-input]').value);
                if (seconds !== null) {
                    audio.currentTime = seconds;
                    audio.play();
                }
            });
        });

        document.querySelectorAll('[data-skip]').forEach((button) => {
            button.addEventListener('click', () => {
                if (!audio) {
                    return;
                }

                const offset = Number(button.dataset.skip || 0);
                audio.currentTime = Math.max(0, Math.min(audio.duration || Infinity, audio.currentTime + offset));
            });
        });

        document.querySelector('[data-audio-play]')?.addEventListener('click', () => {
            audio?.play();
        });

        document.querySelector('[data-audio-pause]')?.addEventListener('click', () => {
            audio?.pause();
        });

        document.querySelector('[data-audio-stop]')?.addEventListener('click', () => {
            if (!audio) {
                return;
            }

            audio.pause();
            audio.currentTime = 0;
        });

        speedSelect?.addEventListener('change', (event) => {
            if (!audio) {
                return;
            }

            audio.playbackRate = Number(event.target.value);
        });
        const isTypingTarget = (element) => ['INPUT', 'TEXTAREA', 'SELECT'].includes(element?.tagName);
        const setSpeedByStep = (direction) => {
            if (!audio || !speedSelect) {
                return;
            }

            const options = Array.from(speedSelect.options);
            const currentIndex = options.findIndex((option) => Number(option.value) === Number(speedSelect.value));
            const nextIndex = Math.max(0, Math.min(options.length - 1, currentIndex + direction));
            speedSelect.value = options[nextIndex].value;
            audio.playbackRate = Number(speedSelect.value);
        };
        const setNearestTimestamp = (kind) => {
            if (!audio) {
                return;
            }

            const activeParagraph = document.activeElement?.closest?.('.paragraph');
            const paragraph = activeParagraph || document.querySelector('.paragraph');
            const input = paragraph?.querySelector(`[name$="[${kind}_time]"]`);
            if (input) {
                input.value = formatTime(audio.currentTime);
            }
        };

        document.addEventListener('keydown', (event) => {
            if (!audio || event.ctrlKey || event.metaKey || event.altKey || isTypingTarget(event.target)) {
                return;
            }

            if (event.code === 'Space') {
                event.preventDefault();
                audio.paused ? audio.play() : audio.pause();
            }

            if (event.key.toLowerCase() === 's') {
                event.preventDefault();
                audio.pause();
                audio.currentTime = 0;
            }

            if (event.key === 'ArrowLeft') {
                event.preventDefault();
                audio.currentTime = Math.max(0, audio.currentTime - 10);
            }

            if (event.key === 'ArrowRight') {
                event.preventDefault();
                audio.currentTime = Math.min(audio.duration || Infinity, audio.currentTime + 10);
            }

            if (event.key === '[') {
                event.preventDefault();
                setSpeedByStep(-1);
            }

            if (event.key === ']') {
                event.preventDefault();
                setSpeedByStep(1);
            }

            if (event.key.toLowerCase() === 'a') {
                event.preventDefault();
                setNearestTimestamp('start');
            }

            if (event.key.toLowerCase() === 'd') {
                event.preventDefault();
                setNearestTimestamp('end');
            }
        });
    </script>
@endsection
