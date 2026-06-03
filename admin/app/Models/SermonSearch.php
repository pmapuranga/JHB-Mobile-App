<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SermonSearch extends Model
{
    protected $table = 'sermon_search';

    protected $primaryKey = 'search_id';

    protected $fillable = [
        'sermon_id',
        'paragraph_id',
        'title',
        'text',
    ];
}
