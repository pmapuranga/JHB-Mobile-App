@extends('layouts.app')

@section('content')
    <div class="toolbar">
        <div>
            <p class="page-kicker">Review</p>
            <h1 style="margin:0">{{ $sermon->title }}</h1>
            <p class="muted" style="margin:6px 0 0">{{ $sermon->code }} &middot; {{ $sermon->place }} &middot; {{ optional($sermon->sermon_date)->format('Y-m-d') }}</p>
        </div>
        <a class="button" href="{{ route('sermons.edit', $sermon) }}">Edit Sermon</a>
    </div>

    <div class="panel">
        <div class="grid two">
            <div><strong>Preacher:</strong> {{ $sermon->preacher ?: 'Not set' }}</div>
            <div><strong>Language:</strong> {{ $sermon->language }}</div>
            <div><strong>Category:</strong> {{ $sermon->category ?: 'Not set' }}</div>
            <div><strong>Audio:</strong> {{ $sermon->audio_file ?: 'Not set' }}</div>
        </div>
        @if ($audioUrl)
            <audio controls src="{{ $audioUrl }}" style="width:100%; margin-top:16px"></audio>
        @endif
    </div>

    <div class="panel" style="margin-top:18px">
        <h2 style="margin-top:0">Transcript</h2>
        @foreach ($sermon->paragraphs as $paragraph)
            <div class="paragraph">
                <strong>{{ $paragraph->paragraph_no }}</strong>
                <span class="muted">
                    @if ($paragraph->start_time_ms || $paragraph->end_time_ms)
                        &middot; {{ $paragraph->start_time_ms ?? 0 }}ms - {{ $paragraph->end_time_ms ?? 0 }}ms
                    @endif
                </span>
                <p style="line-height:1.55">{{ $paragraph->text }}</p>
            </div>
        @endforeach
    </div>
@endsection
