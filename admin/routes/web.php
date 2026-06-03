<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\MobileExportController;
use App\Http\Controllers\SermonController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return redirect()->route('sermons.index');
});

Route::middleware('guest')->group(function () {
    Route::get('login', [AuthController::class, 'showLogin'])->name('login');
    Route::post('login', [AuthController::class, 'login'])->name('login.store');
    Route::get('setup', [AuthController::class, 'showSetup'])->name('setup');
    Route::post('setup', [AuthController::class, 'setup'])->name('setup.store');
});

Route::middleware('auth')->group(function () {
    Route::post('logout', [AuthController::class, 'logout'])->name('logout');
    Route::post('exports/mobile', MobileExportController::class)->name('exports.mobile');
    Route::get('sermons/{sermon}/audio', [SermonController::class, 'audio'])->name('sermons.audio');

    Route::resource('sermons', SermonController::class)
        ->only(['index', 'create', 'store', 'show', 'edit', 'update']);
});
