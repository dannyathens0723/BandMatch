enum PerformanceDomain {
  band('band'),
  dance('dance');

  const PerformanceDomain(this.rpcValue);

  final String rpcValue;

  static PerformanceDomain fromRpcValue(Object? value) {
    return switch (value) {
      'band' => PerformanceDomain.band,
      'dance' => PerformanceDomain.dance,
      _ => throw UnsupportedPerformanceDomainException(value),
    };
  }
}

final class UnsupportedPerformanceDomainException implements Exception {
  const UnsupportedPerformanceDomainException(this.value);

  final Object? value;

  @override
  String toString() => 'Unsupported performance domain: $value';
}
