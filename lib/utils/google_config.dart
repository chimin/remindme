String getGoogleWebClientId() {
  const fromEnv = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  if (fromEnv.isNotEmpty) return fromEnv;
  return '';
}
