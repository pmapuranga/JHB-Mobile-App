<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sermons', function (Blueprint $table) {
            $table->id('sermon_id');
            $table->string('code')->nullable()->index();
            $table->string('title');
            $table->string('preacher')->nullable();
            $table->date('sermon_date')->nullable()->index();
            $table->string('place')->default('JHB, Harare')->index();
            $table->string('language', 12)->default('en')->index();
            $table->string('category')->nullable()->index();
            $table->string('audio_file')->nullable();
            $table->unsignedInteger('duration_seconds')->default(0);
            $table->boolean('is_downloaded')->default(false);
            $table->string('book_id')->nullable()->unique();
            $table->timestamps();
        });

        Schema::create('sermon_paragraphs', function (Blueprint $table) {
            $table->id('paragraph_id');
            $table->foreignId('sermon_id')
                ->constrained('sermons', 'sermon_id')
                ->cascadeOnDelete();
            $table->unsignedInteger('paragraph_no');
            $table->longText('text');
            $table->unsignedInteger('start_time_ms')->nullable();
            $table->unsignedInteger('end_time_ms')->nullable();
            $table->timestamps();
            $table->unique(['sermon_id', 'paragraph_no']);
        });

        Schema::create('sermon_search', function (Blueprint $table) {
            $table->id('search_id');
            $table->foreignId('sermon_id')
                ->constrained('sermons', 'sermon_id')
                ->cascadeOnDelete();
            $table->foreignId('paragraph_id')
                ->constrained('sermon_paragraphs', 'paragraph_id')
                ->cascadeOnDelete();
            $table->string('title');
            $table->longText('text');
            $table->timestamps();
            $table->index(['sermon_id', 'paragraph_id']);
        });

        if (DB::getDriverName() === 'mysql') {
            DB::statement('ALTER TABLE sermon_search ADD FULLTEXT sermon_search_fulltext (title, text)');
        }

        Schema::create('downloads', function (Blueprint $table) {
            $table->id('download_id');
            $table->foreignId('sermon_id')
                ->nullable()
                ->constrained('sermons', 'sermon_id')
                ->nullOnDelete();
            $table->string('audio_url')->nullable();
            $table->string('local_path')->nullable();
            $table->string('file_format', 24)->default('opus');
            $table->timestamp('downloaded_at')->nullable();
            $table->timestamps();
        });

        Schema::create('bookmarks', function (Blueprint $table) {
            $table->id('bookmark_id');
            $table->foreignId('sermon_id')
                ->nullable()
                ->constrained('sermons', 'sermon_id')
                ->cascadeOnDelete();
            $table->foreignId('paragraph_id')
                ->nullable()
                ->constrained('sermon_paragraphs', 'paragraph_id')
                ->nullOnDelete();
            $table->text('note')->nullable();
            $table->timestamp('created_at')->useCurrent();
        });

        Schema::create('highlights', function (Blueprint $table) {
            $table->id('highlight_id');
            $table->foreignId('sermon_id')
                ->nullable()
                ->constrained('sermons', 'sermon_id')
                ->cascadeOnDelete();
            $table->foreignId('paragraph_id')
                ->nullable()
                ->constrained('sermon_paragraphs', 'paragraph_id')
                ->cascadeOnDelete();
            $table->unsignedInteger('start_offset')->nullable();
            $table->unsignedInteger('end_offset')->nullable();
            $table->string('color', 32)->nullable();
            $table->timestamp('created_at')->useCurrent();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('highlights');
        Schema::dropIfExists('bookmarks');
        Schema::dropIfExists('downloads');
        Schema::dropIfExists('sermon_search');
        Schema::dropIfExists('sermon_paragraphs');
        Schema::dropIfExists('sermons');
    }
};
