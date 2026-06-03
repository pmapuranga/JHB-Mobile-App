<div class="table-wrap">
    <table>
        <thead>
            <tr>
                <th>Code</th>
                <th>Title</th>
                <th>Date</th>
                <th>Place</th>
                <th>Audio</th>
                <th>Paragraphs</th>
                <th></th>
            </tr>
        </thead>
        <tbody>
            @forelse ($items as $sermon)
                <tr>
                    <td><span class="badge">{{ $sermon->code ?: 'Draft' }}</span></td>
                    <td>
                        <a href="{{ route('sermons.show', $sermon) }}"><strong>{{ $sermon->title }}</strong></a>
                        <div class="muted">{{ $sermon->category }} &middot; {{ $sermon->language }}</div>
                    </td>
                    <td class="nowrap">{{ optional($sermon->sermon_date)->format('Y-m-d') ?: 'Not set' }}</td>
                    <td>{{ $sermon->place }}</td>
                    <td><span class="file-pill">{{ $sermon->audio_file ?: 'Not set' }}</span></td>
                    <td><strong>{{ $sermon->paragraphs_count }}</strong></td>
                    <td><a class="button secondary" href="{{ route('sermons.edit', $sermon) }}">Edit</a></td>
                </tr>
            @empty
                <tr><td colspan="7" class="muted">No sermons found.</td></tr>
            @endforelse
        </tbody>
    </table>
</div>
