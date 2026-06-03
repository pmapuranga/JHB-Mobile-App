<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Sermon extends Model
{
    use HasFactory;

    protected $primaryKey = 'sermon_id';

    protected $fillable = [
        'code',
        'title',
        'preacher',
        'sermon_date',
        'place',
        'language',
        'category',
        'audio_file',
        'duration_seconds',
        'is_downloaded',
        'book_id',
    ];

    protected function casts(): array
    {
        return [
            'sermon_date' => 'date',
            'duration_seconds' => 'integer',
            'is_downloaded' => 'boolean',
        ];
    }

    public function paragraphs(): HasMany
    {
        return $this->hasMany(SermonParagraph::class, 'sermon_id', 'sermon_id')
            ->orderBy('paragraph_no');
    }
}
