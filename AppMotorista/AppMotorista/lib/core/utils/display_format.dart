String compactDate(String? value) {
  if (value == null || value.isEmpty) return 'Data não informada';
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return '${_two(date.day)}/${_two(date.month)}/${date.year}';
}

String compactTime(String? value) {
  if (value == null || value.isEmpty) return '';
  return value.length >= 5 ? value.substring(0, 5) : value;
}

String _two(int value) => value.toString().padLeft(2, '0');

String stopStatus(String value) => switch (value) {
  'C' => 'Concluída',
  'E' => 'Concluída',
  'P' => 'Pendente',
  'A' => 'Avaria',
  'N' => 'Não entregue',
  'X' => 'Cancelada',
  _ => 'Pendente',
};

String occurrenceStatus(String value) => switch (value) {
  'E' => 'Entregue',
  'P' => 'Pendente',
  _ => value,
};
