import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';

class PetFormProgress extends StatelessWidget {
  const PetFormProgress({required this.currentStep, super.key});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Row(
      children: [
        for (var index = 0; index < 3; index++) ...[
          _PetProgressDot(index: index, currentStep: currentStep),
          if (index < 2)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: index < currentStep
                    ? colors.accent.withValues(alpha: 0.78)
                    : colors.border.withValues(alpha: 0.62),
              ),
            ),
        ],
      ],
    );
  }
}

class PetFormPrimaryButton extends StatelessWidget {
  const PetFormPrimaryButton({
    required this.label,
    required this.isSaving,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool isSaving;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isSaving ? null : () => unawaited(onPressed()),
      child: isSaving
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

class _PetProgressDot extends StatelessWidget {
  const _PetProgressDot({required this.index, required this.currentStep});

  final int index;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isDone = index < currentStep;
    final isActive = index == currentStep;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive ? colors.accent : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDone || isActive
              ? colors.accent
              : colors.border.withValues(alpha: 0.82),
          width: 1.4,
        ),
      ),
      child: isDone
          ? Icon(Icons.check_rounded, size: 17, color: colors.accent)
          : Text(
              '${index + 1}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isActive
                    ? Theme.of(context).colorScheme.onPrimary
                    : colors.textMuted,
                fontWeight: FontWeight.w900,
              ),
            ),
    );
  }
}

class PetNameStep extends StatelessWidget {
  const PetNameStep({
    super.key,
    required this.controller,
    required this.enabled,
    required this.showError,
    required this.text,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool showError;
  final AppLocalizations text;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PetStepHeading(
          title: text.petsNameStepTitle,
          subtitle: text.petsNameStepSubtitle,
        ),
        const SizedBox(height: 18),
        TextField(
          controller: controller,
          maxLength: 40,
          enabled: enabled,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: text.petsNameHint,
            errorText: showError ? text.petsNameRequiredError : null,
            counterStyle: TextStyle(color: colors.textMuted),
          ),
        ),
        Text(
          text.petsNameExample,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.textMuted,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class PetTypeStep extends StatelessWidget {
  const PetTypeStep({
    super.key,
    required this.type,
    required this.breedController,
    required this.enabled,
    required this.text,
    required this.onTypeChanged,
  });

  final String type;
  final TextEditingController breedController;
  final bool enabled;
  final AppLocalizations text;
  final ValueChanged<String> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PetStepHeading(
          title: text.petsTypeBreedTitle,
          subtitle: text.petsTypeBreedStepSubtitle,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _PetTypeChip(
                label: text.petsDogType,
                icon: Icons.pets_rounded,
                selected: type == 'dog',
                onTap: enabled ? () => onTypeChanged('dog') : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PetTypeChip(
                label: text.petsCatType,
                icon: Icons.cruelty_free_outlined,
                selected: type == 'cat',
                onTap: enabled ? () => onTypeChanged('cat') : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PetTypeChip(
                label: text.petsOtherType,
                icon: Icons.inventory_2_outlined,
                selected: type == 'other',
                onTap: enabled ? () => onTypeChanged('other') : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: breedController,
          maxLength: 60,
          enabled: enabled,
          decoration: InputDecoration(
            labelText: text.petsBreedLabel,
            hintText: text.petsBreedHint,
          ),
        ),
      ],
    );
  }
}

class _PetTypeChip extends StatelessWidget {
  const _PetTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? colors.accent.withValues(alpha: 0.18)
              : colors.surface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? colors.accent
                : colors.border.withValues(alpha: 0.7),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? colors.accent : colors.textSoft,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? colors.accent : colors.textSoft,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PetPhotoStep extends StatelessWidget {
  const PetPhotoStep({
    super.key,
    required this.photo,
    required this.enabled,
    required this.text,
    required this.onPickPhoto,
  });

  final XFile? photo;
  final bool enabled;
  final AppLocalizations text;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final selectedPhoto = photo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PetStepHeading(
          title: text.petsPhotoStepTitle,
          subtitle: text.petsPhotoStepSubtitle,
        ),
        const SizedBox(height: 18),
        Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: enabled ? onPickPhoto : null,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surface.withValues(alpha: 0.86),
                border: Border.all(
                  color: colors.accent.withValues(alpha: 0.62),
                  width: 1.5,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: selectedPhoto == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          color: colors.accent,
                          size: 30,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          text.petsAddPhotoAction,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: colors.accent,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          text.petsPhotoFormatHint,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.textMuted, height: 1.15),
                        ),
                      ],
                    )
                  : Image.file(File(selectedPhoto.path), fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          selectedPhoto == null
              ? text.petsAddPhotoLaterHint
              : text.petsPhotoSelectedLabel,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.textMuted,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _PetStepHeading extends StatelessWidget {
  const _PetStepHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colors.textStrong,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textSoft, height: 1.32),
        ),
      ],
    );
  }
}
