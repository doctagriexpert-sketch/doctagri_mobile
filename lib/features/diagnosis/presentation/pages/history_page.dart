import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/diagnosis_result.dart';
import '../../presentation/providers/diagnosis_provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/constants/radius.dart';
import '../../../../core/constants/typography.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<DiagnosisResult>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = context
        .read<DiagnosisProvider>()
        .historyRepository
        .getHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Historique', style: AppTypography.h2),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: () async {
              final historyRepo = context
                  .read<DiagnosisProvider>()
                  .historyRepository;
              await historyRepo.clearHistory();
              setState(() {
                _historyFuture = historyRepo.getHistory();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<DiagnosisResult>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 60, color: AppColors.fog),
                  Gaps.v14,
                  Text(
                    "Aucun historique pour le moment.",
                    style: AppTypography.bodySecondary,
                  ),
                ],
              ),
            );
          }

          final history = snapshot.data!;

          return ListView.builder(
            padding: Spacing.pagePadding,
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 11),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: AppRadius.cardMain,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(11),
                  leading: ClipRRect(
                    borderRadius: AppRadius.small,
                    child:
                        item.imagePath.isNotEmpty &&
                            File(item.imagePath).existsSync()
                        ? Image.file(
                            File(item.imagePath),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            color: AppColors.elevated,
                            child: const Icon(
                              Icons.image_not_supported,
                              color: AppColors.fog,
                            ),
                          ),
                  ),
                  title: Text(item.label, style: AppTypography.h3),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Gaps.v5,
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(item.timestamp),
                        style: AppTypography.caption,
                      ),
                      Gaps.v5,
                      Text(
                        "Confiance: ${(item.confidence * 100).toStringAsFixed(1)}%",
                        style: TextStyle(
                          color: item.confidence > 0.7
                              ? AppColors.healthy
                              : AppColors.warning,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
