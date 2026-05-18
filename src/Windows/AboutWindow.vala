/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText:  2026 Stella & Charlie (teamcons.carrd.co)
 */

public class Jorts.AboutWindow : Granite.AboutDialog {
    public AboutWindow () {
        Object (
            program_name: "JortsMacOS",
            version: "1.0.0",
            comments: _("A delightful sticky note app for macOS"),
            website: "https://github.com/ellie-commons/JORTS_macos",
            logo_icon_name: "jorts",
            developers: {"Stella & Charlie"},
            translator_credits: _("translator-credits")
        );
        set_default_size (600, 400);
    }
}
