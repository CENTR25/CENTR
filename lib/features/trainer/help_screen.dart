import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/theme_redesign.dart';
import '../../models/help_article_model.dart';
import '../../services/help_service.dart';

// ---------------------------------------------------------------------------
// HelpScreen (Figma "Ayuda")
//
// Search field + category chips over an accordion FAQ list, with a WhatsApp /
// Email support footer. FAQ content comes from help_articles.
// ---------------------------------------------------------------------------

// Chip labels and their matching category slugs (index 0 = "Todo" = all).
const List<String> _kChipLabels = ['Todo', 'Alumnos', 'Planes', 'Pagos'];
const List<String?> _kChipSlugs = [null, 'alumnos', 'planes', 'pagos'];

class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  int _selectedChip = 0;
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<HelpArticle> _filter(List<HelpArticle> all) {
    final slug = _kChipSlugs[_selectedChip];
    final q = _query.trim().toLowerCase();
    return all.where((a) {
      if (slug != null && a.category != slug) return false;
      if (q.isEmpty) return true;
      return a.question.toLowerCase().contains(q) ||
          a.answer.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openWhatsapp() async {
    final uri = Uri.tryParse(AppConstants.prgsSupportWhatsappUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.prgsSupportEmail,
      query: 'subject=${Uri.encodeComponent('Soporte PRGS')}',
    );
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final articlesAsync = ref.watch(publishedHelpArticlesProvider);

    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: RedesignColors.primario50, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Ayuda',
            style: RedesignType.bodySm.copyWith(
              fontWeight: FontWeight.w600,
              color: RedesignColors.primario50,
            ),
          ),
          centerTitle: true,
        ),
        body: articlesAsync.when(
          loading: () => const Center(
            child:
                CircularProgressIndicator(color: RedesignColors.actionPrimary),
          ),
          error: (_, __) => const Center(
            child: Text(
              'No se pudo cargar la ayuda',
              style: TextStyle(color: RedesignColors.primario300),
            ),
          ),
          data: (all) {
            final filtered = _filter(all);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                // ── Search ──────────────────────────────────────────────
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  style: RedesignType.bodySm
                      .copyWith(color: RedesignColors.primario50),
                  decoration: const InputDecoration(
                    hintText: 'Buscar en ayuda',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Chips ───────────────────────────────────────────────
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _kChipLabels.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) => _Chip(
                      label: _kChipLabels[i],
                      selected: _selectedChip == i,
                      onTap: () => setState(() => _selectedChip = i),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Preguntas frecuentes',
                  style: RedesignType.bodySm.copyWith(
                    color: RedesignColors.primario50,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),

                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No encontramos resultados.',
                        style: RedesignType.label
                            .copyWith(color: RedesignColors.primario300),
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: RedesignColors.primario700,
                      borderRadius: BorderRadius.circular(RedesignRadius.card),
                      border: Border.all(
                        color:
                            RedesignColors.secundario300.withValues(alpha: 0.18),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < filtered.length; i++) ...[
                          _FaqTile(article: filtered[i]),
                          if (i != filtered.length - 1)
                            const Divider(
                                height: 1,
                                color: RedesignColors.primario600),
                        ],
                      ],
                    ),
                  ),

                const SizedBox(height: 28),

                // ── Support footer ──────────────────────────────────────
                Center(
                  child: Text(
                    '¿No encontrás lo que buscabas?',
                    style: RedesignType.label
                        .copyWith(color: RedesignColors.primario300),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _openWhatsapp,
                        icon: const Icon(Icons.chat_rounded, size: 18),
                        label: const Text('WhatsApp'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openEmail,
                        icon: const Icon(Icons.mail_outline_rounded, size: 18),
                        label: const Text('Email'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _Chip — reuses the dashboard filter-pill look
// ---------------------------------------------------------------------------

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? RedesignColors.secundario300
              : RedesignColors.secundario300.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(RedesignRadius.buttonSm),
          border: Border.all(
            color: RedesignColors.secundario300
                .withValues(alpha: selected ? 1 : 0.4),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: RedesignType.buttonSm.copyWith(
            color: selected
                ? RedesignColors.secundario900
                : RedesignColors.secundario300,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FaqTile — expandable question/answer row
// ---------------------------------------------------------------------------

class _FaqTile extends StatelessWidget {
  final HelpArticle article;

  const _FaqTile({required this.article});

  @override
  Widget build(BuildContext context) {
    return Theme(
      // ExpansionTile draws its own dividers; strip them to match the card.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        iconColor: RedesignColors.primario300,
        collapsedIconColor: RedesignColors.primario300,
        title: Text(
          article.question,
          style: RedesignType.bodySm.copyWith(
            color: RedesignColors.primario50,
            fontWeight: FontWeight.w700,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              article.answer,
              style: RedesignType.label.copyWith(
                color: RedesignColors.primario300,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
