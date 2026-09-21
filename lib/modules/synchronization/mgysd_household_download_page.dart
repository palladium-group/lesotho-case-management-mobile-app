
import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/core/components/circular_process_loader.dart';
import 'package:lncmis_mobile_app/core/services/synchronization_service.dart';
import 'package:lncmis_mobile_app/core/services/user_service.dart';
import 'package:lncmis_mobile_app/core/utils/app_util.dart';
import 'package:lncmis_mobile_app/models/current_user.dart';

class MgysdHouseholdDownloadPage extends StatefulWidget {
  const MgysdHouseholdDownloadPage({super.key});

  @override
  State<MgysdHouseholdDownloadPage> createState() =>
      _MgysdHouseholdDownloadPageState();
}

class _MgysdHouseholdDownloadPageState
    extends State<MgysdHouseholdDownloadPage> {
  final TextEditingController _searchController = TextEditingController();

  SynchronizationService? _service;
  CurrentUser? _currentUser;

  bool _initializing = true;
  bool _searching = false;
  String _downloadingTei = '';
  String _error = '';

  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final user = await UserService().getCurrentUser();
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _error = 'No active user session.';
          _initializing = false;
        });
        return;
      }

      _currentUser = user;
      _service = SynchronizationService(
        user.username,
        user.password,
        user.programs,
        user.userOrgUnitIds,
      );

      if (!mounted) return;
      setState(() => _initializing = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _initializing = false;
      });
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();

    if (query.length < 2) {
      AppUtil.showToastMessage(
        message: 'Enter at least 2 characters to search.',
      );
      return;
    }

    final service = _service;
    final user = _currentUser;
    if (service == null || user == null) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _searching = true;
      _error = '';
      _results = [];
    });

    try {
      final results = await service.searchMgysdHouseholds(user, query);

      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Search failed: $error';
      });
    }
  }

  Future<void> _download(Map<String, dynamic> household) async {
    final service = _service;
    if (service == null) return;

    final tei =
    (household['trackedEntityInstance'] ?? '').toString().trim();
    if (tei.isEmpty) return;

    setState(() {
      _downloadingTei = tei;
      _error = '';
    });

    try {
      final result = await service.downloadMgysdHouseholdBundle(tei);

      if (!mounted) return;
      setState(() => _downloadingTei = '');

      AppUtil.showToastMessage(
        message:
        'Household downloaded: '
            '${result['members']} members, '
            '${result['initialRisk']} Initial Risk assessment(s), '
            '${result['socialInvestigations']} Social Investigation(s).',
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _downloadingTei = '';
        _error = 'Download failed: $error';
      });
    }
  }

  String _displayValue(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? '-' : text;
  }

  Widget _resultCard(Map<String, dynamic> item) {
    final tei =
    (item['trackedEntityInstance'] ?? '').toString().trim();
    final isDownloading = _downloadingTei == tei;

    final fileNumber = _displayValue(item['fileNumber']);
    final district = _displayValue(item['district']);
    final council = _displayValue(item['communityCouncil']);
    final village = _displayValue(item['village']);

    final programs = ((item['programs'] as List?) ?? const [])
        .map((value) => value.toString())
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fileNumber == '-' ? 'Household $tei' : fileNumber,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text('TEI: $tei'),
            Text('District: $district'),
            Text('Community Council: $council'),
            Text('Village: $village'),
            const SizedBox(height: 7),
            Text(
              programs.length > 1
                  ? 'Assessed + Enrolled'
                  : programs.isEmpty
                  ? 'MGYSD Household'
                  : 'MGYSD Household',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _downloadingTei.isNotEmpty
                    ? null
                    : () => _download(item),
                icon: isDownloading
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.download),
                label: Text(
                  isDownloading
                      ? 'Downloading household...'
                      : 'Download this household',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search & Download Household'),
      ),
      body: _initializing
          ? const Center(
        child: CircularProcessLoader(
          color: Colors.blueGrey,
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: 'Search household',
                hintText:
                'File number, household details or DHIS2 UID',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _results = [];
                      _error = '';
                    });
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _searching ? null : _search,
                icon: _searching
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.search),
                label: Text(
                  _searching
                      ? 'Searching DHIS2...'
                      : 'Search DHIS2',
                ),
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error,
                  style: TextStyle(
                    color: Colors.red.shade800,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _searching
                  ? const Center(
                child: CircularProgressIndicator(),
              )
                  : _results.isEmpty
                  ? const Center(
                child: Text(
                  'Search for the household you want to '
                      'make available offline.',
                  textAlign: TextAlign.center,
                ),
              )
                  : ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) =>
                    _resultCard(_results[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
