String getGoogleWebClientId() {
  const fromEnv = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  if (fromEnv.isNotEmpty) return fromEnv;
  return '';
}

String getGoogleIosClientId() =>
    const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
