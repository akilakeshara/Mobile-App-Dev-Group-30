import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class GovEaseShimmerLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final bool isList;
  final int listCount;

  const GovEaseShimmerLoader({
    super.key,
    this.width = double.infinity,
    this.height = 100,
    this.borderRadius = 16,
    this.isList = false,
    this.listCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (isList) {
      return Column(
        children: List.generate(listCount, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Shimmer.fromColors(
              baseColor: Colors.grey.shade200,
              highlightColor: Colors.white,
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
              ),
            ),
          );
        }),
      );
    }
    
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.white,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
