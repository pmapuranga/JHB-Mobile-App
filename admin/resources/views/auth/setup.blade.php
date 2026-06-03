@extends('layouts.app')

@section('content')
    <div class="auth-shell panel">
        <img src="{{ asset('images/jhb-logo.svg') }}" alt="JHB Sermon Admin logo" style="width:138px; display:block; margin:0 auto 12px">
        <h1 style="margin-top:0">Create Admin User</h1>
        <form method="post" action="{{ route('setup.store') }}" class="grid">
            @csrf
            <div>
                <label for="name">Name</label>
                <input id="name" name="name" value="{{ old('name') }}" required autofocus>
                @error('name') <div class="danger">{{ $message }}</div> @enderror
            </div>
            <div>
                <label for="email">Email</label>
                <input id="email" type="text" inputmode="email" autocomplete="email" name="email" value="{{ old('email') }}" required>
                @error('email') <div class="danger">{{ $message }}</div> @enderror
            </div>
            <div>
                <label for="password">Password</label>
                <input id="password" type="password" name="password" required>
                @error('password') <div class="danger">{{ $message }}</div> @enderror
            </div>
            <div>
                <label for="password_confirmation">Confirm Password</label>
                <input id="password_confirmation" type="password" name="password_confirmation" required>
            </div>
            <button type="submit">Create Admin</button>
        </form>
    </div>
@endsection
