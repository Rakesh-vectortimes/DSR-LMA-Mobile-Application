import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_controller.dart';
import 'lma_grade_settings_tab.dart';
import 'lma_question_settings_tab.dart';
import 'lma_section_settings_tab.dart';

class LmaSettingsPage extends ConsumerWidget {
  const LmaSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = ref.watch(authControllerProvider).showLmaSettings;
    if (!allowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('LMA Settings')),
        body: const Center(
          child: Text('LMA settings are not available for this account.'),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('LMA Settings'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Grade Settings'),
              Tab(text: 'Section Settings'),
              Tab(text: 'LMA Question Settings'),
            ],
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'Manage lean maturity assessment sections, grades, and questions.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  LmaGradeSettingsTab(),
                  LmaSectionSettingsTab(),
                  LmaQuestionSettingsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
