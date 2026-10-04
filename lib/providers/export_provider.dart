import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/export_service.dart';

final exportServiceProvider =
    Provider<ExportService>((ref) => ExportService(Supabase.instance.client));
