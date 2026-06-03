@extends('layouts.app')

@section('content')
    <div class="toolbar">
        <div>
            <p class="page-kicker">Ingest</p>
            <h1 style="margin:0">Upload Sermon</h1>
            <p class="muted" style="margin:6px 0 0">Create a sermon from transcript text, a text file, and optional audio.</p>
        </div>
        <a class="button secondary" href="{{ route('sermons.index') }}">Back to Sermons</a>
    </div>

    <form method="post" action="{{ route('sermons.store') }}" enctype="multipart/form-data">
        @csrf

        <div class="panel">
            <h2 style="margin-top:0">Sermon Details</h2>
            <div class="grid two">
                <div>
                    <label for="code">Code</label>
                    <input id="code" name="code" value="{{ old('code') }}" placeholder="09-0602">
                    @error('code') <div class="danger">{{ $message }}</div> @enderror
                </div>
                <div>
                    <label for="title">Title</label>
                    <input id="title" name="title" value="{{ old('title') }}" required>
                    @error('title') <div class="danger">{{ $message }}</div> @enderror
                </div>
                <div>
                    <label for="preacher">Preacher</label>
                    <input id="preacher" name="preacher" value="{{ old('preacher') }}">
                </div>
                <div>
                    <label for="sermon_date">Sermon Date</label>
                    <input id="sermon_date" type="date" name="sermon_date" value="{{ old('sermon_date') }}">
                </div>
                <div>
                    <label for="place">Place</label>
                    <input id="place" name="place" value="{{ old('place', 'JHB, Harare') }}" required>
                </div>
                <div>
                    <label for="language">Language</label>
                    <input id="language" name="language" value="{{ old('language', 'en') }}" required>
                </div>
                <div>
                    <label for="category">Category</label>
                    <input id="category" name="category" value="{{ old('category', 'sermon') }}">
                </div>
                <div>
                    <label for="duration_seconds">Duration Seconds</label>
                    <input id="duration_seconds" type="number" min="0" name="duration_seconds" value="{{ old('duration_seconds', 0) }}">
                </div>
                <label style="display:flex; align-items:center; gap:8px">
                    <input type="checkbox" name="is_downloaded" value="1" @checked(old('is_downloaded')) style="width:auto">
                    Available Offline
                </label>
            </div>
        </div>

        <div class="panel" style="margin-top:18px">
            <h2 style="margin-top:0">Source Files</h2>
            <div class="grid two">
                <div>
                    <label for="transcript_file">Transcript File</label>
                    <input id="transcript_file" type="file" name="transcript_file" accept=".txt,.md,text/plain">
                    @error('transcript_file') <div class="danger">{{ $message }}</div> @enderror
                </div>
                <div>
                    <label for="audio_upload">Audio File</label>
                    <input id="audio_upload" type="file" name="audio_upload" accept=".mp3,.wav,.ogg,.opus,.m4a,.mp4,audio/*">
                    @error('audio_upload') <div class="danger">{{ $message }}</div> @enderror
                </div>
            </div>
            <div style="margin-top:16px">
                <label for="transcript_text">Transcript Text</label>
                <textarea id="transcript_text" name="transcript_text" style="min-height:260px" placeholder="Paste transcript paragraphs here. Blank lines become paragraph breaks.">{{ old('transcript_text') }}</textarea>
                @error('transcript_text') <div class="danger">{{ $message }}</div> @enderror
            </div>
        </div>

        <div style="margin-top:18px">
            <button type="submit">Upload Sermon</button>
        </div>
    </form>
@endsection
