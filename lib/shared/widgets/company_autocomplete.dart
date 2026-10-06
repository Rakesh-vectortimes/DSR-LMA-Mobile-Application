import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/companies/data/company_repository.dart';
import '../../features/companies/data/crm_repository.dart';
import '../../features/companies/data/models/company.dart';
import '../../features/companies/data/models/country.dart';

/// Search/select report companies; creates a new company when the typed name is new.
///
/// With an empty input (or on focus/dropdown tap), lists all companies like a dropdown.
class CompanyAutocompleteField extends ConsumerStatefulWidget {
  const CompanyAutocompleteField({
    super.key,
    required this.values,
    required this.onChanged,
    this.enabled = true,
    this.labelText = 'Company',
    this.convertedTo,
  });

  final CompanyFormValues values;
  final ValueChanged<CompanyFormValues> onChanged;
  final bool enabled;
  final String labelText;

  /// When set, options come from CRM deals converted to this type (4 = LMA, 5 = DSR).
  final int? convertedTo;

  @override
  ConsumerState<CompanyAutocompleteField> createState() =>
      _CompanyAutocompleteFieldState();
}

class _CompanyAutocompleteFieldState extends ConsumerState<CompanyAutocompleteField> {
  late final TextEditingController _nameController;
  late final FocusNode _focusNode;
  Timer? _searchDebounce;
  List<Company> _options = const [];
  List<Country> _countries = const [];
  bool _loading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.values.companyName);
    _focusNode = FocusNode()..addListener(_onFocusChanged);
    _loadCountries();
    // Prefetch so empty-field dropdown can open immediately.
    _searchCompanies('');
  }

  @override
  void didUpdateWidget(covariant CompanyAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values.companyName != widget.values.companyName &&
        _nameController.text != widget.values.companyName) {
      _nameController.text = widget.values.companyName;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _focusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _scheduleSearch(_nameController.text);
    }
  }

  Future<void> _loadCountries() async {
    try {
      final countries = await ref.read(companyRepositoryProvider).listCountries();
      if (mounted) setState(() => _countries = countries);
    } catch (_) {
      // Countries are optional for currency symbol lookup.
    }
  }

  void _scheduleSearch(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      _searchCompanies(query);
    });
  }

  /// Forces [RawAutocomplete] to rebuild its options overlay after async loads.
  void _refreshOptionsOverlay() {
    if (!_focusNode.hasFocus || !mounted) return;
    final current = _nameController.value;
    final offset = current.selection.isValid
        ? current.selection.baseOffset.clamp(0, current.text.length)
        : current.text.length;
    // Flip selection affinity so TextEditingValue changes and options rebuild.
    final affinity = current.selection.affinity == TextAffinity.downstream
        ? TextAffinity.upstream
        : TextAffinity.downstream;
    _nameController.value = TextEditingValue(
      text: current.text,
      selection: TextSelection.collapsed(offset: offset, affinity: affinity),
    );
  }

  Future<void> _searchCompanies(String query) async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final List<Company> resultItems;
      if (widget.convertedTo != null) {
        final converted = await ref.read(crmRepositoryProvider).listConvertedCompanies(
              convertedTo: widget.convertedTo!,
              search: query.trim().isEmpty ? null : query.trim(),
            );
        resultItems = converted
            .map((item) => item.toCompanyOption())
            .where((company) => company.companyName.trim().isNotEmpty)
            .toList();
      } else {
        final result = await ref.read(companyRepositoryProvider).listPage(
              page: 1,
              limit: 100,
              search: query.trim().isEmpty ? null : query.trim(),
            );
        resultItems = result.items;
      }
      if (!mounted) return;
      setState(() {
        _options = resultItems;
        _loading = false;
      });
      _refreshOptionsOverlay();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _options = const [];
        _loading = false;
        _loadError = e.toString();
      });
      _refreshOptionsOverlay();
    }
  }

  void _emit(CompanyFormValues values) => widget.onChanged(values);

  void _applyCompany(Company company) {
    final next = CompanyFormValues.fromCompany(company);
    next.currencySymbol = _currencySymbolFor(company.currency, company.currencySymbol);
    _nameController.text = next.companyName;
    _emit(next);
  }

  String? _currencySymbolFor(String? currency, String? existing) {
    if (existing != null && existing.isNotEmpty) return existing;
    final code = currency?.trim().toUpperCase();
    if (code == null || code.isEmpty) return null;
    for (final country in _countries) {
      if ((country.currency ?? '').trim().toUpperCase() == code) {
        return country.currencySymbol;
      }
    }
    return null;
  }

  Future<void> _selectCompany(Company company) async {
    _applyCompany(company);
    if (company.id.trim().isEmpty) return;
    try {
      final full = await ref.read(companyRepositoryProvider).getById(company.id);
      if (!mounted) return;
      _applyCompany(full);
    } catch (_) {
      // Keep list-row data if detail fetch fails.
    }
  }

  Future<Company?> resolveOrCreateCompany() async {
    final values = widget.values;
    if (values.hasExistingCompany) {
      return ref.read(companyRepositoryProvider).getById(values.companyId!);
    }

    final name = values.companyName.trim();
    if (name.isEmpty) return null;

    final created = await ref.read(companyRepositoryProvider).resolveOrCreate(values);
    if (!mounted) return created;

    final next = CompanyFormValues.fromCompany(created);
    next.currencySymbol = _currencySymbolFor(created.currency, created.currencySymbol);
    _nameController.text = next.companyName;
    _emit(next);
    return created;
  }

  void _onNameChanged(String value) {
    final next = CompanyFormValues(
      companyId: widget.values.companyId,
      companyName: value,
      location: widget.values.location,
      companyIntroduction: widget.values.companyIntroduction,
      totalWorkforce: widget.values.totalWorkforce,
      shiftOperation: widget.values.shiftOperation,
      workingHours: widget.values.workingHours,
      workingDays: widget.values.workingDays,
      currency: widget.values.currency,
      currencySymbol: widget.values.currencySymbol,
      status: widget.values.status,
    );

    if (widget.values.hasExistingCompany) {
      final selected = _options.where((company) => company.id == widget.values.companyId);
      if (selected.isNotEmpty &&
          selected.first.displayName.toLowerCase() != value.trim().toLowerCase()) {
        next.clearCompanyLink();
      }
    }

    _emit(next);
    _scheduleSearch(value);
  }

  void _onNameBlur() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      final cleared = CompanyFormValues(
        companyName: '',
        location: widget.values.location,
        companyIntroduction: widget.values.companyIntroduction,
        totalWorkforce: widget.values.totalWorkforce,
        shiftOperation: widget.values.shiftOperation,
        workingHours: widget.values.workingHours,
        workingDays: widget.values.workingDays,
        currency: widget.values.currency,
        currencySymbol: widget.values.currencySymbol,
        status: widget.values.status,
      );
      _emit(cleared);
      return;
    }

    final exact = _options.where(
      (company) => company.displayName.toLowerCase() == name.toLowerCase(),
    );
    if (exact.isNotEmpty) {
      _selectCompany(exact.first);
      return;
    }

    if (widget.convertedTo != null) {
      return;
    }

    final next = CompanyFormValues.fromCompany(
      Company(
        id: '',
        companyName: name,
        location: widget.values.location,
        companyIntroduction: widget.values.companyIntroduction,
        totalWorkforce: widget.values.totalWorkforce,
        shiftOperation: widget.values.shiftOperation,
        workingHours: widget.values.workingHours,
        workingDays: widget.values.workingDays,
        currency: widget.values.currency,
        currencySymbol: widget.values.currencySymbol,
        status: widget.values.status,
      ),
    )..clearCompanyLink();
    _emit(next);
  }

  void _openDropdown() {
    if (!widget.enabled) return;
    _focusNode.requestFocus();
    // Empty query → full company list; otherwise filter by current text.
    _searchCompanies(_nameController.text);
  }

  Iterable<Company> _filteredOptions(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return _options;
    return _options.where(
      (company) => company.displayName.toLowerCase().contains(normalized),
    );
  }

  String? _validateSelection() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return 'Select a company';
    if (widget.convertedTo == null) return null;
    final matchesOption = _options.any(
      (company) => company.displayName.toLowerCase() == name.toLowerCase(),
    );
    if (matchesOption) return null;
    if (widget.values.companyName.trim().toLowerCase() == name.toLowerCase()) {
      return null;
    }
    return 'Select a company from the list';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RawAutocomplete<Company>(
          textEditingController: _nameController,
          focusNode: _focusNode,
          optionsBuilder: (textEditingValue) {
            return _filteredOptions(textEditingValue.text);
          },
          displayStringForOption: (company) => company.displayName,
          onSelected: _selectCompany,
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return Focus(
              onFocusChange: (hasFocus) {
                if (!hasFocus) _onNameBlur();
              },
              child: TextFormField(
                controller: controller,
                focusNode: focusNode,
                enabled: widget.enabled,
                decoration: InputDecoration(
                  labelText: widget.labelText,
                  hintText: widget.convertedTo == null
                      ? 'Select or type a company'
                      : 'Select a company',
                  prefixIcon: const Icon(Icons.business_outlined),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      IconButton(
                        tooltip: 'Show companies',
                        onPressed: widget.enabled ? _openDropdown : null,
                        icon: const Icon(Icons.arrow_drop_down),
                      ),
                    ],
                  ),
                ),
                onChanged: _onNameChanged,
                onFieldSubmitted: (_) => onFieldSubmitted(),
                validator: (_) => _validateSelection(),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            if (options.isEmpty) {
              if (_loading) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 280, maxHeight: 56),
                      child: const ListTile(
                        dense: true,
                        title: Text('Loading companies...'),
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280, minWidth: 280),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final company = options.elementAt(index);
                      return ListTile(
                        title: Text(company.displayName),
                        subtitle: company.location.isNotEmpty
                            ? Text(company.location)
                            : null,
                        onTap: () => onSelected(company),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        if (_loadError != null) ...[
          const SizedBox(height: 8),
          Text(
            _loadError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
          ),
        ],
        if (widget.values.location.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Location: ${widget.values.location}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}
