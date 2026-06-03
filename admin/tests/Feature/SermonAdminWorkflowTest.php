<?php

namespace Tests\Feature;

use App\Models\Sermon;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class SermonAdminWorkflowTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_upload_audio_and_create_sermon(): void
    {
        Storage::fake('public');

        $user = User::factory()->create();

        $response = $this->actingAs($user)->post(route('sermons.store'), [
            'code' => '26-0516',
            'title' => 'Workflow Upload Test',
            'place' => 'JHB, Harare',
            'language' => 'en',
            'category' => 'sermon',
            'duration_seconds' => 120,
            'transcript_text' => "First paragraph.\n\nSecond paragraph.",
            'audio_upload' => UploadedFile::fake()->create('workflow-test.opus', 128, 'audio/ogg'),
        ]);

        $response->assertRedirect();

        $sermon = Sermon::where('title', 'Workflow Upload Test')->firstOrFail();

        $this->assertNotNull($sermon->audio_file);
        $this->assertSame(2, $sermon->paragraphs()->count());
        Storage::disk('public')->assertExists('audios/'.$sermon->audio_file);
    }

    public function test_admin_can_append_paragraphs_to_existing_sermon(): void
    {
        $user = User::factory()->create();
        $sermon = Sermon::create([
            'code' => '26-0516',
            'title' => 'Append Paragraph Test',
            'place' => 'JHB, Harare',
            'language' => 'en',
            'category' => 'sermon',
        ]);

        $sermon->paragraphs()->create([
            'paragraph_no' => 1,
            'text' => 'Existing paragraph.',
        ]);

        $response = $this->actingAs($user)->put(route('sermons.update', $sermon), [
            'code' => $sermon->code,
            'title' => $sermon->title,
            'place' => $sermon->place,
            'language' => $sermon->language,
            'category' => $sermon->category,
            'duration_seconds' => 0,
            'new_paragraphs' => "Added paragraph one.\n\nAdded paragraph two.",
        ]);

        $response->assertRedirect(route('sermons.edit', $sermon));

        $this->assertSame(3, $sermon->paragraphs()->count());
        $this->assertDatabaseHas('sermon_paragraphs', [
            'sermon_id' => $sermon->sermon_id,
            'paragraph_no' => 3,
            'text' => 'Added paragraph two.',
        ]);
    }
}
