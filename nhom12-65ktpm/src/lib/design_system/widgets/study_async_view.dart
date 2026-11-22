import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'study_empty.dart';
import 'study_error.dart';
import 'study_loading.dart';

// Widget dùng chung: Loading -> Data/Empty -> Error, không lặp UI ở từng module.
class StudyAsyncView<T> extends StatelessWidget {
  const StudyAsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.isEmpty,
    this.onRetry,
    this.emptyMessage = 'Chưa có dữ liệu.',
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final bool Function(T data)? isEmpty;
  final VoidCallback? onRetry;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const StudyLoading(),
      error: (error, stackTrace) => StudyError(onRetry: onRetry),
      data: (data) {
        if (isEmpty?.call(data) ?? false) {
          return StudyEmpty(message: emptyMessage);
        }
        return builder(data);
      },
    );
  }
}
