import 'package:flutter/foundation.dart';
import 'android_google_account_provider.dart';
import 'flutter_google_account_provider.dart';
import 'google_account_provider.dart';

GoogleAccountProvider createGoogleAccountProvider() =>
    defaultTargetPlatform == TargetPlatform.android
    ? AndroidGoogleAccountProvider()
    : FlutterGoogleAccountProvider();
