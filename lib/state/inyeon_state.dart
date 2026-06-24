// App state used by Riverpod to power all screens.
import '../models/occasion_record.dart';
import '../models/person.dart';

class InyeonState {
  const InyeonState({
    required this.isLoading,
    required this.people,
    required this.records,
    this.errorMessage,
  });

  const InyeonState.loading()
    : this(isLoading: true, people: const [], records: const []);

  final bool isLoading;
  final List<Person> people;
  final List<OccasionRecord> records;
  final String? errorMessage;

  InyeonState copyWith({
    bool? isLoading,
    List<Person>? people,
    List<OccasionRecord>? records,
    String? errorMessage,
  }) {
    return InyeonState(
      isLoading: isLoading ?? this.isLoading,
      people: people ?? this.people,
      records: records ?? this.records,
      errorMessage: errorMessage,
    );
  }
}
