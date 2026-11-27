class EndpointChangeResult {
  const EndpointChangeResult._(this.saved, this.message);

  const EndpointChangeResult.saved(String message) : this._(true, message);
  const EndpointChangeResult.blocked(String message) : this._(false, message);

  final bool saved;
  final String message;
}
