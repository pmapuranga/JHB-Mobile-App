<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SermonParagraph extends Model
{
    use HasFactory;

    protected $primaryKey = 'paragraph_id';

    protected $fillable = [
        'sermon_id',
        'paragraph_no',
        'text',
        'start_time_ms',
        'end_time_ms',
    ];

    protected function casts(): array
    {
        return [
            'paragraph_no' => 'integer',
            'start_time_ms' => 'integer',
            'end_time_ms' => 'integer',
        ];
    }

    public function sermon(): BelongsTo
    {
        return $this->belongsTo(Sermon::class, 'sermon_id', 'sermon_id');
    }
}
