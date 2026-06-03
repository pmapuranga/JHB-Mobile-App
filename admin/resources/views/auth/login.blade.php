@extends('layouts.app')

@section('content')
    <div class="auth-shell panel">
        <img src="{{ asset('images/jhb-logo.svg') }}" alt="JHB Sermon Admin logo" style="width:138px; display:block; margin:0 auto 12px">
        <h1 style="margin-top:0">Admin Login</h1>
        <form method="post" action="{{ route('login.store') }}" class="grid">
            @csrf
            <div>
                <label for="email">Email</label>
                <input id="email" type="text" inputmode="email" autocomplete="email" name="email" value="{{ old('email') }}" required autofocus>
                @error('email') <div class="danger">{{ $message }}</div> @enderror
            </div>
            <div>
                <label for="password">Password</label>
                <input id="password" type="password" name="password" required>
                @error('password') <div class="danger">{{ $message }}</div> @enderror
            </div>
            <label style="display:flex; align-items:center; gap:8px">
                <input type="checkbox" name="remember" value="1" style="width:auto">
                Remember this browser
            </label>
            <button type="submit">Sign in</button>
        </form>
    </div>
@endsection
