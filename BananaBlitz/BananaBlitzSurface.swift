import AppKit
import SwiftUI

/// Everything the shared Settings, About, menu and menu bar surfaces need to
/// know about BananaBlitz. Defined once here; the shared code never branches
/// on the app name.
extension SurfaceApp {
    static let bananaBlitz = SurfaceApp(
        wordmark: SurfaceWordmark(lead: "Banana", accent: "Blitz"),
        accent: .bananaGold,
        summary: "A menu bar utility that clears telemetry, intelligence and tracking data out of your ~/Library on a schedule you choose.",
        capabilities: [
            SurfaceCapability("Three cleaning levels",
                              detail: "Basic, Strong and Paranoid presets; 26 targets, each with a stated side effect."),
            SurfaceCapability("Three strategies per target",
                              detail: "Wipe the contents, delete only the databases, or lock the path with an immutable file."),
            SurfaceCapability("Dry run",
                              detail: "See every target, action, item count and byte size at risk before anything is touched."),
            SurfaceCapability("Scheduled cleaning",
                              detail: "Every 1 to 24 hours or on demand, with catch-up after sleep or relaunch."),
            SurfaceCapability("Recovery built in",
                              detail: "A generated unbrick script reverses every lock; local snapshots on request."),
            SurfaceCapability("Guardrails",
                              detail: "Nothing outside ~/Library is ever touched, and a self-test reports what is reachable."),
        ],
        distribution: .openSource(
            repository: URL(string: "https://github.com/adamXbot/BananaBlitz")!,
            issues: URL(string: "https://github.com/adamXbot/BananaBlitz/issues")!,
            licence: "MIT License"
        ),
        shape: .menuBarUtility,
        acknowledgements: [
            SurfaceAcknowledgement(
                name: "Sparkle",
                licence: "MIT License, with the licences of its bundled components",
                text: BananaBlitzSurface.sparkleLicence
            ),
        ]
    )
}

/// App-specific pieces the surfaces are given: the release notes link, the
/// mark in the menu bar popover header and the bundled licence texts.
enum BananaBlitzSurface {
    /// Where "Release Notes" in the Updates pane goes.
    static let releaseNotes = URL(string: "https://github.com/adamXbot/BananaBlitz/releases")!

    /// The real app icon at header size, for `SurfacePopoverHeader`.
    @MainActor
    static var popoverMark: Image {
        guard let source = NSApplication.shared.applicationIconImage else {
            return Image(nsImage: MenuBarIconStyle.monoBananaTemplate)
        }
        let sized = NSImage(size: NSSize(width: 22, height: 22), flipped: false) { rect in
            source.draw(in: rect)
            return true
        }
        return Image(nsImage: sized)
    }

    /// Sparkle's LICENSE file, reproduced in full for the Acknowledgements sheet.
    static let sparkleLicence = """
        Copyright (c) 2006-2013 Andy Matuschak.
        Copyright (c) 2009-2013 Elgato Systems GmbH.
        Copyright (c) 2011-2014 Kornel Lesiński.
        Copyright (c) 2015-2017 Mayur Pawashe.
        Copyright (c) 2014 C.W. Betts.
        Copyright (c) 2014 Petroules Corporation.
        Copyright (c) 2014 Big Nerd Ranch.
        All rights reserved.

        Permission is hereby granted, free of charge, to any person obtaining a copy of
        this software and associated documentation files (the "Software"), to deal in
        the Software without restriction, including without limitation the rights to
        use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
        the Software, and to permit persons to whom the Software is furnished to do so,
        subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
        FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
        COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
        IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
        CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

        =================
        EXTERNAL LICENSES
        =================

        bspatch.c and bsdiff.c, from bsdiff 4.3 <http://www.daemonology.net/bsdiff/>:

        Copyright 2003-2005 Colin Percival
        All rights reserved

        Redistribution and use in source and binary forms, with or without
        modification, are permitted providing that the following conditions 
        are met:
        1. Redistributions of source code must retain the above copyright
           notice, this list of conditions and the following disclaimer.
        2. Redistributions in binary form must reproduce the above copyright
           notice, this list of conditions and the following disclaimer in the
           documentation and/or other materials provided with the distribution.

        THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
        IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
        WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
        ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
        DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
        DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
        OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
        HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
        STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
        IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
        POSSIBILITY OF SUCH DAMAGE.

        --

        sais.c and sais.h, from sais-lite (2010/08/07) <https://sites.google.com/site/yuta256/sais>:

        The sais-lite copyright is as follows:

        Copyright (c) 2008-2010 Yuta Mori All Rights Reserved.

        Permission is hereby granted, free of charge, to any person
        obtaining a copy of this software and associated documentation
        files (the "Software"), to deal in the Software without
        restriction, including without limitation the rights to use,
        copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the
        Software is furnished to do so, subject to the following
        conditions:

        The above copyright notice and this permission notice shall be
        included in all copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
        EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
        OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
        NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
        HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
        WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
        FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
        OTHER DEALINGS IN THE SOFTWARE.

        --

        Portable C implementation of Ed25519, from https://github.com/orlp/ed25519

        Copyright (c) 2015 Orson Peters <orsonpeters@gmail.com>

        This software is provided 'as-is', without any express or implied warranty. In no event will the
        authors be held liable for any damages arising from the use of this software.

        Permission is granted to anyone to use this software for any purpose, including commercial
        applications, and to alter it and redistribute it freely, subject to the following restrictions:

        1. The origin of this software must not be misrepresented; you must not claim that you wrote the
           original software. If you use this software in a product, an acknowledgment in the product
           documentation would be appreciated but is not required.

        2. Altered source versions must be plainly marked as such, and must not be misrepresented as
           being the original software.

        3. This notice may not be removed or altered from any source distribution.

        --

        SUSignatureVerifier.m:

        Copyright (c) 2011 Mark Hamlin.

        All rights reserved.

        Redistribution and use in source and binary forms, with or without
        modification, are permitted providing that the following conditions
        are met:
        1. Redistributions of source code must retain the above copyright
           notice, this list of conditions and the following disclaimer.
        2. Redistributions in binary form must reproduce the above copyright
           notice, this list of conditions and the following disclaimer in the
           documentation and/or other materials provided with the distribution.

        THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
        IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
        WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
        ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
        DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
        DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
        OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
        HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
        STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
        IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
        POSSIBILITY OF SUCH DAMAGE.
        """
}
