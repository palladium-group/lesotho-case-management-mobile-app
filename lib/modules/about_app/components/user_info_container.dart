import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/app_state/current_user_state/current_user_state.dart';
import 'package:lncmis_mobile_app/app_state/language_translation_state/language_translation_state.dart';
import 'package:lncmis_mobile_app/models/current_user.dart';
import 'package:lncmis_mobile_app/modules/about_app/utils/about_page_util.dart';
import 'package:provider/provider.dart';

class UserInfoContainer extends StatelessWidget {
  const UserInfoContainer({
    Key? key,
    required this.currentLanguage,
  }) : super(key: key);

  final String currentLanguage;

  static const Color lncmisBlue = Color(0xFF0D47A1);

  String _display(String? value) {
    final String v = (value ?? '').trim();
    return v.isEmpty ? 'Not captured' : v;
  }

  String _initials(String? name, String? username) {
    final String nameValue = (name ?? '').trim();
    final String usernameValue = (username ?? '').trim();
    final String source = nameValue.isNotEmpty ? nameValue : usernameValue;

    if (source.isEmpty) return 'U';

    final List<String> parts = source
        .split(RegExp(r'\s+'))
        .where((String part) => part.trim().isNotEmpty)
        .toList();

    if (parts.length >= 2) {
      return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'
          .toUpperCase();
    }

    return source.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageTranslationState>(
      builder: (context, languageState, child) {
        final bool isSesotho = languageState.currentLanguage == 'lesotho';

        return Consumer<CurrentUserState>(
          builder: (context, currentUserState, child) {
            final CurrentUser? currentUser = currentUserState.currentUser;
            final String currentUserLocations =
                (currentUserState.currentUserLocations).trim();

            final String fullName = _display(currentUser?.name);
            final String username = _display(currentUser?.username);
            final String roles = _display(currentUser?.userRoles);

            return AboutPageUtil.collapsibleSectionCard(
              initiallyExpanded: false,
              title: isSesotho ? 'Lintlha tsa Mosebelisi' : 'Signed-in User',
              subtitle: isSesotho
                  ? 'Account, roles, groups le libaka tse abetsoeng.'
                  : 'Account, roles, groups and assigned locations.',
              icon: Icons.person_pin_circle_outlined,
              color: lncmisBlue,
              trailingLabel: roles == 'Not captured' ? null : roles,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        lncmisBlue.withOpacity(0.075),
                        const Color(0xFF1976D2).withOpacity(0.040),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: lncmisBlue.withOpacity(0.10)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 29,
                        backgroundColor: lncmisBlue.withOpacity(0.12),
                        child: Text(
                          _initials(currentUser?.name, currentUser?.username),
                          style: const TextStyle(
                            color: lncmisBlue,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              username,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                            if (roles != 'Not captured') ...[
                              const SizedBox(height: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: lncmisBlue.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  roles,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: lncmisBlue,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10.8,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AboutPageUtil.infoTile(
                  label: isSesotho ? 'Mabitso a feletseng' : 'Full Name',
                  value: fullName,
                  icon: Icons.person_outline,
                  color: lncmisBlue,
                ),
                AboutPageUtil.infoTile(
                  label: isSesotho ? 'Lebitso la mosebelisi' : 'Username',
                  value: username,
                  icon: Icons.account_circle_outlined,
                  color: Colors.indigo,
                ),
                AboutPageUtil.infoTile(
                  label: isSesotho ? 'Email' : 'Email',
                  value: _display(currentUser?.email),
                  icon: Icons.email_outlined,
                  color: Colors.deepPurple,
                ),
                AboutPageUtil.infoTile(
                  label: isSesotho ? 'Nomoro ea mohala' : 'Phone Number',
                  value: _display(currentUser?.phoneNumber),
                  icon: Icons.phone_outlined,
                  color: Colors.teal,
                ),
                AboutPageUtil.infoTile(
                  label: isSesotho ? 'Libaka tse abetsoeng' : 'Assigned Locations',
                  value: currentUserLocations.isEmpty
                      ? 'Not captured'
                      : currentUserLocations,
                  icon: Icons.location_on_outlined,
                  color: Colors.orange,
                ),
                AboutPageUtil.infoTile(
                  label: isSesotho ? 'Mesebetsi e abetsoeng' : 'Assigned Roles',
                  value: roles,
                  icon: Icons.admin_panel_settings_outlined,
                  color: Colors.green,
                ),
                AboutPageUtil.infoTile(
                  label: isSesotho ? 'Lihlopha tse abetsoeng' : 'Assigned Groups',
                  value: _display(currentUser?.userGroups),
                  icon: Icons.groups_2_outlined,
                  color: Colors.blueGrey,
                ),
              ],
            );
          },
        );
      },
    );
  }
}
