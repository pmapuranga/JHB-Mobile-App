<?php

namespace App\Http\Controllers;

use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Artisan;
use Throwable;

class MobileExportController extends Controller
{
    public function __invoke(): RedirectResponse
    {
        try {
            $exitCode = Artisan::call('sermons:export-mobile');
            $output = trim(Artisan::output());
        } catch (Throwable $exception) {
            return back()->withErrors([
                'export' => 'Mobile export failed: '.$exception->getMessage(),
            ]);
        }

        if ($exitCode !== 0) {
            return back()->withErrors([
                'export' => $output ?: 'Mobile export failed.',
            ]);
        }

        return back()->with('status', $output ?: 'Mobile package exported.');
    }
}
