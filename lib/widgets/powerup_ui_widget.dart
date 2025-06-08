// widgets/powerup_ui_widget.dart
// This file exports all powerup UI components for easy importing

// Export all powerup UI components
export '../utils/powerup_utils.dart';
export 'powerup_inventory_widget.dart';
export 'powerup_effects_widget.dart';
export 'powerup_overlays_widget.dart';
export 'powerup_animations_widget.dart';

// Re-export the main classes for backward compatibility
// This allows existing imports to continue working

// Re-export main widgets for easy access
export 'powerup_inventory_widget.dart' show PowerupInventory, PowerupInventoryItem;
export 'powerup_effects_widget.dart' show PowerupEffectsDisplay, PowerupEffectChip;
export 'powerup_overlays_widget.dart' show FreezeOverlay, SolutionOverlay;
export 'powerup_animations_widget.dart' show PowerupSpawnAnimation, PowerupNotification;
export '../utils/powerup_utils.dart' show PowerupUtils;