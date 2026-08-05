import 'chat_theme.dart';

enum PrivacyVisibility { everyone, contacts, nobody }

enum AppThemePreference { system, light, dark }

enum WhoCanMessage { everyone, contacts }

/// Visual design language for the whole app.
enum DesignSystem {
  hux,
  ios,
  parinox,
  shadcn,
  shadcnFlutter,
  nes,
  moon,
}

/// Bottom navigation chrome style.
enum NavBarStyle {
  floating,
  docked,
  minimal,
  curved,
  notch,
}

/// Client-side preferences (Telegram-style privacy, media, storage).
class AppSettings {
  const AppSettings({
    this.lastSeen = PrivacyVisibility.everyone,
    this.profilePhoto = PrivacyVisibility.everyone,
    this.bio = PrivacyVisibility.everyone,
    this.forwardedMessages = PrivacyVisibility.everyone,
    this.whoCanMessage = WhoCanMessage.everyone,
    this.readReceipts = true,
    this.typingIndicators = true,
    this.linkPreviews = true,
    this.inviteViaLink = true,
    this.notifyPrivate = true,
    this.notifyGroups = true,
    this.notifyChannels = true,
    this.notifyCalls = true,
    this.notifyMentions = true,
    this.notificationPreview = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.autoDlPhotosWifi = true,
    this.autoDlPhotosMobile = true,
    this.autoDlVideosWifi = true,
    this.autoDlVideosMobile = false,
    this.autoDlFilesWifi = false,
    this.autoDlFilesMobile = false,
    this.saveToGallery = false,
    this.enterToSend = false,
    this.mediaCompression = true,
    this.fontScale = 1.0,
    this.theme = AppThemePreference.system,
    this.designSystem = DesignSystem.hux,
    this.navBarStyle = NavBarStyle.floating,
    this.chatThemeId = 'classic',
    this.customChatThemes = const [],
    this.noiseCancellation = true,
    this.autoClearCache = false,
    this.cacheKeepDays = 30,
    this.useLessData = false,
  });

  final PrivacyVisibility lastSeen;
  final PrivacyVisibility profilePhoto;
  final PrivacyVisibility bio;
  final PrivacyVisibility forwardedMessages;
  final WhoCanMessage whoCanMessage;
  final bool readReceipts;
  final bool typingIndicators;
  final bool linkPreviews;
  final bool inviteViaLink;

  final bool notifyPrivate;
  final bool notifyGroups;
  final bool notifyChannels;
  final bool notifyCalls;
  final bool notifyMentions;
  final bool notificationPreview;
  final bool soundEnabled;
  final bool vibrationEnabled;

  final bool autoDlPhotosWifi;
  final bool autoDlPhotosMobile;
  final bool autoDlVideosWifi;
  final bool autoDlVideosMobile;
  final bool autoDlFilesWifi;
  final bool autoDlFilesMobile;
  final bool saveToGallery;

  final bool enterToSend;
  final bool mediaCompression;
  final double fontScale;
  final AppThemePreference theme;
  final DesignSystem designSystem;
  final NavBarStyle navBarStyle;
  final String chatThemeId;
  final List<ChatThemeConfig> customChatThemes;
  final bool noiseCancellation;
  final bool autoClearCache;
  final int cacheKeepDays;
  final bool useLessData;

  static const defaults = AppSettings();

  ChatThemeConfig get activeChatTheme =>
      ChatThemePresets.byId(chatThemeId, custom: customChatThemes);

  AppSettings copyWith({
    PrivacyVisibility? lastSeen,
    PrivacyVisibility? profilePhoto,
    PrivacyVisibility? bio,
    PrivacyVisibility? forwardedMessages,
    WhoCanMessage? whoCanMessage,
    bool? readReceipts,
    bool? typingIndicators,
    bool? linkPreviews,
    bool? inviteViaLink,
    bool? notifyPrivate,
    bool? notifyGroups,
    bool? notifyChannels,
    bool? notifyCalls,
    bool? notifyMentions,
    bool? notificationPreview,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? autoDlPhotosWifi,
    bool? autoDlPhotosMobile,
    bool? autoDlVideosWifi,
    bool? autoDlVideosMobile,
    bool? autoDlFilesWifi,
    bool? autoDlFilesMobile,
    bool? saveToGallery,
    bool? enterToSend,
    bool? mediaCompression,
    double? fontScale,
    AppThemePreference? theme,
    DesignSystem? designSystem,
    NavBarStyle? navBarStyle,
    String? chatThemeId,
    List<ChatThemeConfig>? customChatThemes,
    bool? noiseCancellation,
    bool? autoClearCache,
    int? cacheKeepDays,
    bool? useLessData,
  }) {
    return AppSettings(
      lastSeen: lastSeen ?? this.lastSeen,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      bio: bio ?? this.bio,
      forwardedMessages: forwardedMessages ?? this.forwardedMessages,
      whoCanMessage: whoCanMessage ?? this.whoCanMessage,
      readReceipts: readReceipts ?? this.readReceipts,
      typingIndicators: typingIndicators ?? this.typingIndicators,
      linkPreviews: linkPreviews ?? this.linkPreviews,
      inviteViaLink: inviteViaLink ?? this.inviteViaLink,
      notifyPrivate: notifyPrivate ?? this.notifyPrivate,
      notifyGroups: notifyGroups ?? this.notifyGroups,
      notifyChannels: notifyChannels ?? this.notifyChannels,
      notifyCalls: notifyCalls ?? this.notifyCalls,
      notifyMentions: notifyMentions ?? this.notifyMentions,
      notificationPreview: notificationPreview ?? this.notificationPreview,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      autoDlPhotosWifi: autoDlPhotosWifi ?? this.autoDlPhotosWifi,
      autoDlPhotosMobile: autoDlPhotosMobile ?? this.autoDlPhotosMobile,
      autoDlVideosWifi: autoDlVideosWifi ?? this.autoDlVideosWifi,
      autoDlVideosMobile: autoDlVideosMobile ?? this.autoDlVideosMobile,
      autoDlFilesWifi: autoDlFilesWifi ?? this.autoDlFilesWifi,
      autoDlFilesMobile: autoDlFilesMobile ?? this.autoDlFilesMobile,
      saveToGallery: saveToGallery ?? this.saveToGallery,
      enterToSend: enterToSend ?? this.enterToSend,
      mediaCompression: mediaCompression ?? this.mediaCompression,
      fontScale: fontScale ?? this.fontScale,
      theme: theme ?? this.theme,
      designSystem: designSystem ?? this.designSystem,
      navBarStyle: navBarStyle ?? this.navBarStyle,
      chatThemeId: chatThemeId ?? this.chatThemeId,
      customChatThemes: customChatThemes ?? this.customChatThemes,
      noiseCancellation: noiseCancellation ?? this.noiseCancellation,
      autoClearCache: autoClearCache ?? this.autoClearCache,
      cacheKeepDays: cacheKeepDays ?? this.cacheKeepDays,
      useLessData: useLessData ?? this.useLessData,
    );
  }

  Map<String, Object?> toJson() => {
        'lastSeen': lastSeen.name,
        'profilePhoto': profilePhoto.name,
        'bio': bio.name,
        'forwardedMessages': forwardedMessages.name,
        'whoCanMessage': whoCanMessage.name,
        'readReceipts': readReceipts,
        'typingIndicators': typingIndicators,
        'linkPreviews': linkPreviews,
        'inviteViaLink': inviteViaLink,
        'notifyPrivate': notifyPrivate,
        'notifyGroups': notifyGroups,
        'notifyChannels': notifyChannels,
        'notifyCalls': notifyCalls,
        'notifyMentions': notifyMentions,
        'notificationPreview': notificationPreview,
        'soundEnabled': soundEnabled,
        'vibrationEnabled': vibrationEnabled,
        'autoDlPhotosWifi': autoDlPhotosWifi,
        'autoDlPhotosMobile': autoDlPhotosMobile,
        'autoDlVideosWifi': autoDlVideosWifi,
        'autoDlVideosMobile': autoDlVideosMobile,
        'autoDlFilesWifi': autoDlFilesWifi,
        'autoDlFilesMobile': autoDlFilesMobile,
        'saveToGallery': saveToGallery,
        'enterToSend': enterToSend,
        'mediaCompression': mediaCompression,
        'fontScale': fontScale,
        'theme': theme.name,
        'designSystem': designSystem.name,
        'navBarStyle': navBarStyle.name,
        'chatThemeId': chatThemeId,
        'customChatThemes': customChatThemes.map((e) => e.toJson()).toList(),
        'noiseCancellation': noiseCancellation,
        'autoClearCache': autoClearCache,
        'cacheKeepDays': cacheKeepDays,
        'useLessData': useLessData,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    PrivacyVisibility vis(String key, PrivacyVisibility fallback) {
      final raw = json[key] as String?;
      return PrivacyVisibility.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => fallback,
      );
    }

    T enumOr<T extends Enum>(List<T> values, String? raw, T fallback) {
      return values.firstWhere((e) => e.name == raw, orElse: () => fallback);
    }

    return AppSettings(
      lastSeen: vis('lastSeen', PrivacyVisibility.everyone),
      profilePhoto: vis('profilePhoto', PrivacyVisibility.everyone),
      bio: vis('bio', PrivacyVisibility.everyone),
      forwardedMessages: vis('forwardedMessages', PrivacyVisibility.everyone),
      whoCanMessage: enumOr(
        WhoCanMessage.values,
        json['whoCanMessage'] as String?,
        WhoCanMessage.everyone,
      ),
      readReceipts: json['readReceipts'] as bool? ?? true,
      typingIndicators: json['typingIndicators'] as bool? ?? true,
      linkPreviews: json['linkPreviews'] as bool? ?? true,
      inviteViaLink: json['inviteViaLink'] as bool? ?? true,
      notifyPrivate: json['notifyPrivate'] as bool? ?? true,
      notifyGroups: json['notifyGroups'] as bool? ?? true,
      notifyChannels: json['notifyChannels'] as bool? ?? true,
      notifyCalls: json['notifyCalls'] as bool? ?? true,
      notifyMentions: json['notifyMentions'] as bool? ?? true,
      notificationPreview: json['notificationPreview'] as bool? ?? true,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
      autoDlPhotosWifi: json['autoDlPhotosWifi'] as bool? ?? true,
      autoDlPhotosMobile: json['autoDlPhotosMobile'] as bool? ?? true,
      autoDlVideosWifi: json['autoDlVideosWifi'] as bool? ?? true,
      autoDlVideosMobile: json['autoDlVideosMobile'] as bool? ?? false,
      autoDlFilesWifi: json['autoDlFilesWifi'] as bool? ?? false,
      autoDlFilesMobile: json['autoDlFilesMobile'] as bool? ?? false,
      saveToGallery: json['saveToGallery'] as bool? ?? false,
      enterToSend: json['enterToSend'] as bool? ?? false,
      mediaCompression: json['mediaCompression'] as bool? ?? true,
      fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
      theme: enumOr(
        AppThemePreference.values,
        json['theme'] as String?,
        AppThemePreference.system,
      ),
      designSystem: enumOr(
        DesignSystem.values,
        json['designSystem'] as String?,
        DesignSystem.hux,
      ),
      navBarStyle: enumOr(
        NavBarStyle.values,
        json['navBarStyle'] as String?,
        NavBarStyle.floating,
      ),
      chatThemeId: json['chatThemeId'] as String? ?? 'classic',
      customChatThemes: (json['customChatThemes'] as List?)
              ?.whereType<Map>()
              .map((e) => ChatThemeConfig.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      noiseCancellation: json['noiseCancellation'] as bool? ?? true,
      autoClearCache: json['autoClearCache'] as bool? ?? false,
      cacheKeepDays: json['cacheKeepDays'] as int? ?? 30,
      useLessData: json['useLessData'] as bool? ?? false,
    );
  }
}

String privacyLabel(PrivacyVisibility v) => switch (v) {
      PrivacyVisibility.everyone => 'Everybody',
      PrivacyVisibility.contacts => 'My contacts',
      PrivacyVisibility.nobody => 'Nobody',
    };

String whoCanMessageLabel(WhoCanMessage v) => switch (v) {
      WhoCanMessage.everyone => 'Everybody',
      WhoCanMessage.contacts => 'My contacts',
    };

String themeLabel(AppThemePreference v) => switch (v) {
      AppThemePreference.system => 'System default',
      AppThemePreference.light => 'Light',
      AppThemePreference.dark => 'Dark',
    };

String designSystemLabel(DesignSystem v) => switch (v) {
      DesignSystem.hux => 'Hux UI',
      DesignSystem.ios => 'iOS',
      DesignSystem.parinox => 'Parinox',
      DesignSystem.shadcn => 'shadcn/ui',
      DesignSystem.shadcnFlutter => 'shadcn_flutter',
      DesignSystem.nes => 'NES UI',
      DesignSystem.moon => 'Moon Design',
    };

String designSystemSubtitle(DesignSystem v) => switch (v) {
      DesignSystem.hux => 'Default — Hux buttons, inputs, cards & tokens',
      DesignSystem.ios => 'Cupertino-inspired blues, blur chrome',
      DesignSystem.parinox => 'Telegram-style Parinox theme',
      DesignSystem.shadcn => 'Zinc / Inter via shadcn_ui',
      DesignSystem.shadcnFlutter => 'Zinc look from shadcn_flutter package',
      DesignSystem.nes => '8-bit retro console UI',
      DesignSystem.moon => 'Moon Design System tokens',
    };

String navBarStyleLabel(NavBarStyle v) => switch (v) {
      NavBarStyle.floating => 'Floating',
      NavBarStyle.docked => 'Docked',
      NavBarStyle.minimal => 'Minimal',
      NavBarStyle.curved => 'Curved',
      NavBarStyle.notch => 'Notch',
    };

String navBarStyleSubtitle(NavBarStyle v) => switch (v) {
      NavBarStyle.floating => 'Pill bar floating above content',
      NavBarStyle.docked => 'Full-width bar at the bottom',
      NavBarStyle.minimal => 'Compact icons with less chrome',
      NavBarStyle.curved => 'CurvedNavigationBar arc style',
      NavBarStyle.notch => 'Animated notch bottom bar',
    };
