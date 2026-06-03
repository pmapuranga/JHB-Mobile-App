@extends('layouts.app')

@section('content')
    <div class="toolbar">
        <div>
            <p class="page-kicker">Library</p>
            <h1 style="margin:0">Sermons</h1>
            <p class="muted" style="margin:6px 0 0">Manage transcript text, metadata, audio references, and mobile export readiness.</p>
        </div>
        <div class="toolbar-actions">
            <a class="button" href="{{ route('sermons.create') }}">Upload Sermon</a>
            <form method="post" action="{{ route('exports.mobile') }}" style="margin:0">
                @csrf
                <button class="secondary" type="submit">Export Mobile Package</button>
            </form>
        </div>
    </div>

    <form method="get" class="panel flat filter-panel">
        <div>
            <label for="q">Search</label>
            <input id="q" name="q" value="{{ $search }}" placeholder="Search title, code, place">
        </div>
        <div>
            <label for="group_by">Group by</label>
            <select id="group_by" name="group_by">
                <option value="none" @selected($groupBy === 'none')>No grouping</option>
                <option value="year" @selected($groupBy === 'year')>Year</option>
                <option value="month" @selected($groupBy === 'month')>Month</option>
                <option value="place" @selected($groupBy === 'place')>Place</option>
                <option value="preacher" @selected($groupBy === 'preacher')>Preacher</option>
                <option value="category" @selected($groupBy === 'category')>Category</option>
            </select>
        </div>
        <button type="submit">Apply</button>
    </form>

    @if ($groupedSermons)
        @forelse ($groupedSermons as $groupName => $items)
            <section class="group-section">
                <div class="group-heading">
                    <h2>{{ $groupName }}</h2>
                    <span class="count-pill">{{ $items->count() }} {{ Str::plural('sermon', $items->count()) }}</span>
                </div>
                @include('sermons._table', ['items' => $items])
            </section>
        @empty
            <div class="panel muted">No sermons found.</div>
        @endforelse
    @else
        @include('sermons._table', ['items' => $sermons])
        <div style="margin-top:16px">{{ $sermons->links() }}</div>
    @endif
@endsection
