import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../src/runtime/intercom_runtime_cache.dart';

class SelectedSociety {
  final int? socId;

  const SelectedSociety({this.socId});
}

class SelectedFlatState {
  final SelectedSociety? selectedSociety;

  const SelectedFlatState({this.selectedSociety});
}

/// Minimal replacement for the app's SelectedFlat provider.
///
/// This module uses it only as a synchronous "best effort" cache for soc_id.
final selectedFlatProvider = Provider<SelectedFlatState>((ref) {
  return SelectedFlatState(
    selectedSociety: SelectedSociety(
      socId: IntercomRuntimeCache.selectedSocietyId,
    ),
  );
});

