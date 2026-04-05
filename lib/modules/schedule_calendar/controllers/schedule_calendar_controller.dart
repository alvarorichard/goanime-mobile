import 'package:flutter/material.dart';
import 'package:goanime/modules/schedule_calendar/schedule_calendar.dart';
import 'package:goanime/services/locale_service.dart';
import 'package:intl/intl.dart';

class ScheduleCalendarController extends ChangeNotifier {
  final ScheduleService _scheduleService = ScheduleService();
  final LocaleService? localeService;

  ScheduleCalendarController({this.localeService});

  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay;
  List<ScheduleEntryModel> _selectedDayEntries = [];
  bool _isLoadingDay = false;
  bool _isOutOfRange = false;

  // Cache por data específica (YYYY-MM-dd-weekday)
  final Map<String, List<ScheduleEntryModel>> _dayCache = {};
  // Cache geral da temporada
  List<ScheduleEntryModel>? _cachedSeasonEntries;

  String get _localeCode => localeService?.locale.languageCode ?? 'pt';

  // Getters
  DateTime get focusedMonth => _focusedMonth;
  DateTime? get selectedDay => _selectedDay;
  List<ScheduleEntryModel> get selectedDayEntries => _selectedDayEntries;
  bool get isLoadingDay => _isLoadingDay;
  bool get isOutOfRange => _isOutOfRange;
  bool get hasSelectedDay => _selectedDay != null;

  String get selectedDayName {
    if (_selectedDay == null) return '';
    final locale = _localeCode == 'pt' ? 'pt_BR' : 'en_US';
    final dayName = DateFormat('EEEE', locale).format(_selectedDay!);
    return dayName[0].toUpperCase() + dayName.substring(1);
  }

  String get selectedDayFormatted {
    if (_selectedDay == null) return '';
    final locale = _localeCode == 'pt' ? 'pt_BR' : 'en_US';
    final format = _localeCode == 'pt' ? "d 'de' MMMM" : 'MMMM d';
    return DateFormat(format, locale).format(_selectedDay!);
  }

  void initialize() {
    _selectedDay = DateTime.now();
    _loadDaySchedule(_selectedDay!);
  }

  Future<void> _loadDaySchedule(DateTime day) async {
    _isLoadingDay = true;
    _isOutOfRange = false;
    _selectedDay = day;
    notifyListeners();

    final cacheKey = '${DateFormat('yyyy-MM-dd').format(day)}-${day.weekday}';

    // Verifica cache da data específica
    if (_dayCache.containsKey(cacheKey)) {
      _selectedDayEntries = _dayCache[cacheKey]!;
      _isLoadingDay = false;
      notifyListeners();
      debugPrint('[CalendarController] ✅ Using cached entries for $cacheKey');
      return;
    }

    try {
      debugPrint(
        '[CalendarController] 🔄 Fetching anime for ${DateFormat('EEEE, dd/MM/yyyy').format(day)}...',
      );

      // Busca entradas da temporada atual
      final allSeasonEntries =
          _cachedSeasonEntries ?? await _scheduleService.getSeasonSchedule();
      _cachedSeasonEntries = allSeasonEntries;

      // Filtra pelo dia da semana e remove duplicatas
      final uniqueEntries = <int, ScheduleEntryModel>{};
      for (final entry in allSeasonEntries) {
        if (entry.dayOfWeek == day.weekday) {
          // Se já existe, mantém a primeira (melhor qualidade de dados)
          if (!uniqueEntries.containsKey(entry.malId)) {
            uniqueEntries[entry.malId] = entry;
          }
        }
      }

      final dayEntries = uniqueEntries.values.toList();
      dayEntries.sort((a, b) => a.airDate.compareTo(b.airDate));

      _dayCache[cacheKey] = dayEntries;
      _selectedDayEntries = dayEntries;
      _isLoadingDay = false;
      notifyListeners();
      debugPrint(
        '[CalendarController] ✅ Found ${dayEntries.length} entries for ${DateFormat('EEEE').format(day)}',
      );
    } catch (e) {
      debugPrint('[CalendarController] ❌ Error loading day: $e');
      _selectedDayEntries = [];
      _isLoadingDay = false;
      notifyListeners();
    }
  }

  void onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    _selectedDay = selectedDay;
    _focusedMonth = focusedDay;
    notifyListeners();
    _loadDaySchedule(selectedDay);
  }

  void onPageChanged(DateTime focusedDay) {
    _focusedMonth = focusedDay;
    notifyListeners();
  }

  void clearCache() {
    _dayCache.clear();
    _cachedSeasonEntries = null;
    _selectedDayEntries.clear();
    _isOutOfRange = false;
    notifyListeners();
  }
}
