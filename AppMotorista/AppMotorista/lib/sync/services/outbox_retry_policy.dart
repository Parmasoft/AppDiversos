class OutboxRetryPolicy {
  const OutboxRetryPolicy({
    this.initialDelay = const Duration(seconds: 5),
    this.maximumDelay = const Duration(minutes: 5),
  });

  final Duration initialDelay;
  final Duration maximumDelay;

  Duration delayFor({required String operationGuid, required int attempt}) {
    var milliseconds = initialDelay.inMilliseconds;
    for (var index = 1; index < attempt; index++) {
      milliseconds = (milliseconds * 2).clamp(0, maximumDelay.inMilliseconds);
    }
    milliseconds = milliseconds.clamp(0, maximumDelay.inMilliseconds);

    var seed = attempt;
    for (final unit in operationGuid.codeUnits) {
      seed = ((seed * 31) + unit) & 0x7fffffff;
    }
    final jitterPercent = 80 + (seed % 41);
    final jittered = (milliseconds * jitterPercent) ~/ 100;
    return Duration(
      milliseconds: jittered.clamp(0, maximumDelay.inMilliseconds),
    );
  }
}
