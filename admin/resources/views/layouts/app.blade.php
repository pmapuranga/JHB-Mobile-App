<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ config('app.name', 'JHB Sermon Admin') }}</title>
    <style>
        :root {
            color-scheme: light;
            font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            --ink: #201715;
            --muted: #6f6661;
            --line: #e6ded8;
            --surface: #ffffff;
            --surface-soft: #fbf8f5;
            --brand: #c91d1d;
            --brand-dark: #8e1717;
            --gold: #f2bd20;
            --green: #147d57;
            --shadow: 0 14px 34px rgba(53, 31, 24, .09);
        }
        * { box-sizing: border-box; }
        body { margin: 0; background: #f7f3ef; color: var(--ink); }
        body::before { content: ""; position: fixed; inset: 0 0 auto; height: 220px; background: linear-gradient(135deg, #fff8eb 0%, #fff 47%, #fbe9e7 100%); z-index: -1; }
        a { color: var(--brand-dark); text-decoration: none; }
        a:hover { text-decoration: underline; }
        .app-header { position: sticky; top: 0; z-index: 20; background: rgba(255, 255, 255, .92); border-bottom: 1px solid rgba(230, 222, 216, .9); backdrop-filter: blur(14px); }
        .header-inner { max-width: 1240px; margin: 0 auto; padding: 14px 24px; display: flex; align-items: center; justify-content: space-between; gap: 18px; }
        .brand-lockup { display: inline-flex; align-items: center; gap: 12px; color: var(--ink); text-decoration: none; min-width: 220px; }
        .brand-lockup:hover { text-decoration: none; }
        .brand-logo { width: 70px; height: 42px; object-fit: contain; filter: drop-shadow(0 8px 12px rgba(201, 29, 29, .12)); }
        .brand-title { display: grid; gap: 2px; }
        .brand-title strong { font-size: 16px; line-height: 1.1; }
        .brand-title span { color: var(--muted); font-size: 12px; font-weight: 700; text-transform: uppercase; }
        nav { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; justify-content: flex-end; }
        nav a, nav button.link { border-radius: 999px; color: var(--ink); font-weight: 800; padding: 9px 12px; }
        nav a:hover, nav button.link:hover { background: #f5ebe6; text-decoration: none; }
        main { max-width: 1240px; margin: 0 auto; padding: 28px 24px 44px; }
        h1, h2, h3 { letter-spacing: 0; }
        h1 { font-size: 30px; line-height: 1.1; }
        h2 { font-size: 22px; }
        h3 { font-size: 16px; }
        .button, button { display: inline-flex; align-items: center; justify-content: center; gap: 8px; border: 0; border-radius: 7px; padding: 10px 14px; background: var(--brand); color: white; font-weight: 800; cursor: pointer; text-decoration: none; min-height: 40px; }
        .button:hover { text-decoration: none; }
        .button.secondary, button.secondary { background: #3d302b; }
        .button.subtle, button.subtle { background: #f2ebe6; color: var(--ink); border: 1px solid var(--line); }
        button.link { background: transparent; border: 0; padding: 0; color: inherit; font: inherit; font-weight: 800; min-height: 0; }
        .panel { background: rgba(255, 255, 255, .94); border: 1px solid var(--line); border-radius: 8px; padding: 20px; box-shadow: var(--shadow); }
        .panel.flat { box-shadow: none; }
        .grid { display: grid; gap: 16px; }
        .grid.two { grid-template-columns: repeat(2, minmax(0, 1fr)); }
        .grid.three { grid-template-columns: repeat(3, minmax(0, 1fr)); }
        .table-wrap { overflow-x: auto; border: 1px solid var(--line); border-radius: 8px; background: var(--surface); box-shadow: var(--shadow); }
        table { width: 100%; border-collapse: collapse; min-width: 850px; }
        th, td { padding: 14px 16px; border-bottom: 1px solid #eee7e2; text-align: left; vertical-align: middle; }
        th { background: var(--surface-soft); font-size: 12px; text-transform: uppercase; color: #6c5b54; }
        tbody tr:hover { background: #fffaf3; }
        tbody tr:last-child td { border-bottom: 0; }
        input, textarea, select { width: 100%; border: 1px solid #d9cdc5; border-radius: 7px; padding: 10px 11px; font: inherit; background: white; color: var(--ink); }
        input:focus, textarea:focus, select:focus { border-color: var(--brand); box-shadow: 0 0 0 3px rgba(201, 29, 29, .12); outline: none; }
        textarea { min-height: 110px; resize: vertical; line-height: 1.5; }
        label { display: block; font-weight: 800; color: #3c302b; margin-bottom: 6px; }
        .muted { color: var(--muted); }
        .toolbar { display: flex; justify-content: space-between; align-items: flex-start; gap: 18px; margin-bottom: 20px; }
        .toolbar-actions { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; justify-content: flex-end; }
        .page-kicker { color: var(--brand-dark); font-weight: 900; font-size: 12px; text-transform: uppercase; margin: 0 0 8px; }
        .status { background: #edfdf5; border: 1px solid #b8ecd4; color: #075b3c; border-radius: 8px; padding: 12px 14px; margin-bottom: 16px; }
        .error { background: #fff1f1; border: 1px solid #fac8c8; color: #8f1414; border-radius: 8px; padding: 12px 14px; margin-bottom: 16px; }
        .danger { color: #b91c1c; font-size: 13px; margin-top: 5px; }
        .paragraph { border-top: 1px solid var(--line); padding: 16px 0 0; margin-top: 16px; transition: background .18s ease, border-color .18s ease, box-shadow .18s ease; }
        .paragraph.is-current { border-color: rgba(201, 29, 29, .32); border-radius: 8px; background: #fff6dc; box-shadow: inset 4px 0 0 var(--brand); padding: 16px 14px 14px; }
        .paragraph.is-current h3 { color: var(--brand-dark); }
        .timestamp-tools { display: grid; grid-template-columns: 1fr auto auto; gap: 8px; align-items: end; }
        .auth-shell { max-width: 480px; margin: 54px auto; }
        .badge { display: inline-flex; align-items: center; border-radius: 999px; padding: 4px 9px; background: #fff3d7; color: #6e4510; font-size: 12px; font-weight: 900; }
        .file-pill { display: inline-block; max-width: 240px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: var(--muted); }
        .nowrap { white-space: nowrap; }
        .group-section { margin-bottom: 18px; }
        .group-heading { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 10px; }
        .group-heading h2 { margin: 0; }
        .count-pill { display: inline-flex; align-items: center; border-radius: 999px; padding: 5px 10px; background: #f2ebe6; color: #3d302b; font-size: 12px; font-weight: 900; }
        .filter-panel { display: grid; grid-template-columns: minmax(220px, 1fr) 220px auto; gap: 10px; margin-bottom: 18px; align-items: end; }
        .sticky-audio-rail { position: sticky; top: 86px; z-index: 12; margin: -8px -8px 16px; padding: 14px 14px 16px; border: 1px solid rgba(230, 222, 216, .95); border-radius: 8px; background: rgba(255, 255, 255, .96); box-shadow: 0 16px 32px rgba(53, 31, 24, .12); backdrop-filter: blur(12px); }
        .sticky-audio-rail h2 { margin: 0 0 10px; }
        .sticky-audio-rail audio { display: block; width: 100%; }
        .audio-transport { display: grid; grid-template-columns: auto minmax(220px, 1fr) auto auto; align-items: center; gap: 10px; margin-bottom: 10px; padding: 8px 10px; border: 1px solid var(--line); border-radius: 8px; background: #fffdfb; }
        .transport-buttons { display: flex; align-items: center; gap: 5px; }
        .transport-icon { width: 30px; height: 30px; min-height: 30px; border-radius: 999px; padding: 0; font-size: 12px; line-height: 1; box-shadow: none; font-weight: 900; }
        .transport-icon.primary { width: 34px; height: 34px; min-height: 34px; background: var(--brand); color: white; font-size: 14px; }
        .transport-icon.secondary-dark { background: #3d302b; color: white; }
        .progress-wrap { display: flex; align-items: center; gap: 10px; min-width: 0; }
        .audio-progress { flex: 1; width: 100%; cursor: pointer; margin: 0; height: 20px; accent-color: var(--brand); }
        .audio-progress::-webkit-slider-runnable-track { height: 5px; border-radius: 999px; background: #ded7d2; }
        .audio-progress::-webkit-slider-thumb { margin-top: -6px; width: 17px; height: 17px; border-radius: 999px; background: var(--brand); border: 0; }
        .audio-progress::-moz-range-track { height: 5px; border-radius: 999px; background: #ded7d2; }
        .audio-progress::-moz-range-thumb { width: 17px; height: 17px; border-radius: 999px; background: var(--brand); border: 0; }
        .time-readout { min-width: 92px; color: var(--muted); font-size: 12px; font-weight: 900; line-height: 1; white-space: nowrap; text-align: right; }
        .speed-control { display: flex; align-items: center; gap: 7px; color: var(--muted); font-size: 12px; font-weight: 900; white-space: nowrap; }
        .speed-control select { width: auto; min-width: 68px; padding: 6px 26px 6px 9px; font-size: 13px; font-weight: 900; min-height: 32px; border-radius: 7px; }
        .shortcut-hints { display: flex; gap: 5px 8px; flex-wrap: wrap; margin-top: 5px; color: var(--muted); font-size: 10px; font-weight: 700; opacity: .78; }
        .shortcut-hints kbd { border: 1px solid var(--line); border-radius: 4px; background: var(--surface-soft); padding: 1px 4px; color: var(--ink); font: inherit; font-size: 10px; font-weight: 900; }
        .transcript-add { border: 1px solid var(--line); border-radius: 8px; background: var(--surface-soft); padding: 16px; margin-bottom: 18px; }
        .transcript-add h3 { margin: 0 0 8px; }
        @media (max-width: 760px) {
            .header-inner { align-items: flex-start; flex-direction: column; }
            nav { justify-content: flex-start; }
            main { padding: 22px 16px 34px; }
            .grid.two, .grid.three { grid-template-columns: 1fr; }
            .toolbar { align-items: stretch; flex-direction: column; }
            .toolbar-actions { justify-content: flex-start; }
            .timestamp-tools { grid-template-columns: 1fr; }
            .brand-lockup { min-width: 0; }
            .filter-panel { grid-template-columns: 1fr; }
            .sticky-audio-rail { top: 118px; margin-left: -4px; margin-right: -4px; }
            .audio-transport { grid-template-columns: 1fr; gap: 10px; }
            .transport-buttons { justify-content: center; }
            .progress-wrap { flex-wrap: wrap; }
            .time-readout { text-align: left; }
            .speed-control { justify-content: space-between; }
        }
    </style>
</head>
<body>
    <header class="app-header">
        <div class="header-inner">
            <a class="brand-lockup" href="{{ route('sermons.index') }}">
                <img class="brand-logo" src="{{ asset('images/jhb-logo.svg') }}" alt="JHB Sermon Admin logo">
                <span class="brand-title">
                    <strong>JHB Sermon Admin</strong>
                    <span>Mobile library console</span>
                </span>
            </a>
            @auth
                <nav>
                    <a href="{{ route('sermons.index') }}">Sermons</a>
                    <a href="{{ route('sermons.create') }}">Upload</a>
                    <form method="post" action="{{ route('exports.mobile') }}" style="margin:0">
                        @csrf
                        <button class="link" type="submit">Export Mobile Package</button>
                    </form>
                    <form method="post" action="{{ route('logout') }}" style="margin:0">
                        @csrf
                        <button class="link" type="submit">Sign out</button>
                    </form>
                </nav>
            @endauth
        </div>
    </header>
    <main>
        @if (session('status'))
            <div class="status">{{ session('status') }}</div>
        @endif
        @if ($errors->any())
            <div class="error">
                <strong>Please fix the highlighted fields.</strong>
                @if ($errors->has('export'))
                    <div>{{ $errors->first('export') }}</div>
                @endif
            </div>
        @endif

        @yield('content')
    </main>
</body>
</html>
