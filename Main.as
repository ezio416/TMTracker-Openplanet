/*
c 2023-05-14
m 2023-05-25
*/

void Main() {
    if (Settings::loadMyMapsOnBoot)
        DB::MyMaps::Load();

    if (Settings::loadRecordsOnBoot)
        DB::Records::Load();

    if (Settings::loadZonesOnBoot)
        Zones::Load();

    if (!Settings::rememberOpen)
        Settings::windowOpen = false;

    IO::CreateFolder(Storage::thumbnailFolder);

    NadeoServices::AddAudience("NadeoLiveServices");
}

void RenderMenu() {
	if (UI::MenuItem(Storage::title, "", Settings::windowOpen))
		Settings::windowOpen = !Settings::windowOpen;
}

void RenderInterface() {
    if (!Settings::windowOpen) return;

    if (Settings::DetectSortMapsNewest())
        DB::MyMaps::Load();

    UI::SetNextWindowSize(600, 540, UI::Cond::FirstUseEver);
    UI::SetNextWindowPos(100, 100, UI::Cond::FirstUseEver);

    UI::Begin(Storage::title, Settings::windowOpen);
        UI::Text("Welcome to TMTracker! Check out these tabs to see what the plugin offers:");
        RenderTabs();
    UI::End();
}

void RenderTabs() {
    UI::BeginTabBar("tabs");
        RenderMapsTab();
        // RenderRecordsTab();
        // RenderAccountsTab();
        RenderInfoTab();
        if (Storage::dev) RenderDevTab();
    UI::EndTabBar();
}

void RenderMapsTab() {
    if (!UI::BeginTabItem(Icons::Map + " Maps")) return;

    UI::TextWrapped(
        "Once you've updated your maps, click on a thumbnail to open a tab for that map. " +
        "Close tabs with the 'X' or with a middle click."
    );

    if (UI::Button(Icons::Refresh + " Update Map List (" + Storage::myMaps.Length + ")"))
        startnew(CoroutineFunc(Maps::GetMyMapsCoro));

    if (Storage::myHiddenMaps.Length > 0) {
        UI::SameLine();
        if (UI::Button(Icons::Eye + " Show Hidden (" + Storage::myHiddenMaps.Length + ")")) {
            string timerId = Various::LogTimerStart("unhiding all maps");

            for (uint i = 0; i < Storage::myHiddenMaps.Length;)
                DB::MyMaps::UnHide(Storage::myHiddenMaps[i]);

            for (uint i = 0; i < Storage::currentMaps.Length; i++)
                Storage::currentMaps[i].hidden = false;

            Various::LogTimerEnd(timerId);
        }
    }

    if (Storage::currentMaps.Length > 0) {
        UI::SameLine();
        if (UI::Button(Icons::Times + " Clear Current Maps (" + Storage::currentMaps.Length + ")"))
            Storage::ClearCurrentMaps();
    }

    UI::Separator();

    Storage::mapClicked = false;

    UI::BeginTabBar("MyMapsTabs");
        RenderMyMapListTab();
        RenderMyMapsTabs();
    UI::EndTabBar();

    UI::EndTabItem();
}

void RenderMyMapListTab() {
    if (!UI::BeginTabItem(Icons::Map + " Map List " + Icons::Map)) return;

    uint currentX = 0;
    auto size = UI::GetWindowSize();

    for (uint i = 0; i < Storage::myMaps.Length; i++) {
        auto map = Storage::myMaps[i];

        currentX += Settings::myMapsThumbnailWidthList;
        if (i > 0 && currentX < uint(size.x))
            UI::SameLine();

        UI::BeginGroup();
            auto pos = UI::GetCursorPos();
            auto thumbSize = vec2(Settings::myMapsThumbnailWidthList, Settings::myMapsThumbnailWidthList);
            try   { UI::Image(map.thumbnailTexture, thumbSize); }
            catch { UI::Image(Storage::defaultTexture, thumbSize); }

            UI::SetCursorPos(pos);
            if (UI::InvisibleButton("invis_" + map.mapUid, thumbSize)) {
                if (!Storage::currentMapUids.Exists(map.mapUid)) {
                    Storage::currentMapUids.Set(map.mapUid, "");
                    Storage::currentMaps.InsertLast(@Storage::myMaps[i]);
                }
                Storage::mapClicked = true;
            }

            currentX = uint(UI::GetCursorPos().x) + Settings::myMapsThumbnailWidthList + 44;
            UI::PushTextWrapPos(currentX - 44);  // 44 pixels for scrollbar works on 1.5x scaling at 4K
            UI::Text((Settings::myMapsListColor) ? map.mapNameColor : map.mapNameText);
            UI::PopTextWrapPos();
            UI::Text("\n");
        UI::EndGroup();
    }

    UI::EndTabItem();
}

void RenderMyMapsTabs() {
    for (uint i = 0; i < Storage::currentMaps.Length; i++) {
        auto map = @Storage::currentMaps[i];

        uint flags = UI::TabItemFlags::Trailing;
        if (
            Storage::mapClicked &&
            Settings::myMapsSwitchOnClicked &&
            i == Storage::currentMaps.Length - 1
        ) {
            flags |= UI::TabItemFlags::SetSelected;
            Storage::mapClicked = false;
        }

        string tabTitle = Settings::myMapsTabsColor ? map.mapNameColor : map.mapNameText;
        if (UI::BeginTabItem(tabTitle, Storage::currentMaps[i].viewing, flags)) {
            UI::BeginGroup();
                auto thumbSize = vec2(Settings::myMapsThumbnailWidthTabs, Settings::myMapsThumbnailWidthTabs);
                try   { UI::Image(map.thumbnailTexture, thumbSize); }
                catch { UI::Image(Storage::defaultTexture, thumbSize); }

                UI::SameLine();
                UI::BeginGroup();
                    UI::Text(map.mapNameText);
                    UI::Text(Time::FormatStringUTC(Settings::dateFormat + "UTC", map.timestamp));
                    UI::Text(Time::FormatString(Settings::dateFormat + "Local", map.timestamp));
                    UI::Text("\\$4B0" + Icons::Circle + " " + Time::Format(map.authorTime));
                    UI::Text("\\$DD1" + Icons::Circle + " " + Time::Format(map.goldTime));
                    UI::Text("\\$AAA" + Icons::Circle + " " + Time::Format(map.silverTime));
                    UI::Text("\\$C80" + Icons::Circle + " " + Time::Format(map.bronzeTime));
                UI::EndGroup();

                if (map.hidden) {
                    if (UI::Button(Icons::Eye + " Show This Map (currently hidden)")) {
                        Storage::currentMaps[i].hidden = false;
                        DB::MyMaps::UnHide(map);
                    }
                } else {
                    if (UI::Button(Icons::EyeSlash + " Hide This Map")) {
                        Storage::currentMaps[i].hidden = true;
                        DB::MyMaps::Hide(map);
                    }
                }
            UI::EndGroup();

            UI::SameLine();
            UI::BeginGroup();
                if (UI::Button(Icons::Download + " Get Records (" + Storage::currentMaps[i].records.Length + ")"))
                    startnew(CoroutineFunc(map.GetRecordsCoro));

                UI::SameLine();
                UI::Text(
                    "Last Updated: " + (
                        map.recordsTimestamp > 0 ?
                            Time::FormatString(Settings::dateFormat + "Local\\$Z", map.recordsTimestamp) +
                                " (" + Various::FormatSeconds(Time::Stamp - map.recordsTimestamp) + " ago)" :
                            "not yet"
                    )
                );

                for (uint j = 0; j < map.records.Length; j++) {
                    UI::Text(
                        map.records[j].position + " - " +
                        Time::Format(map.records[j].time) + " - " +
                        map.records[j].accountName + " - " +
                        map.records[j].zoneName
                    );
                }
            UI::EndGroup();

            UI::EndTabItem();
        }

        if (!Storage::currentMaps[i].viewing) {
            Storage::currentMaps.RemoveAt(i);
            Storage::currentMapUids.Delete(map.mapUid);
        }
    }
}

void RenderRecordsTab() {
    if (!UI::BeginTabItem(Icons::Trophy + " Records")) return;
    UI::EndTabItem();
}

void RenderAccountsTab() {
    if (!UI::BeginTabItem(Icons::User + " Accounts")) return;
    UI::EndTabItem();
}

void RenderInfoTab() {
    if (!UI::BeginTabItem(Icons::Info + " Info")) return;

    UI::TextWrapped(
        "TMTracker is a project I started back in December of 2022. It was first written in Python, then C#, "    +
        "and now Angelscript, with each iteration having slightly different features. I plan for this to be "     +
        "the final iteration, and there will be more features to come, such as:\n\n - adding other maps and "     +
        "campaigns, such as the current map or from TMX\n - tracking personal records on maps and campaigns\n - " +
        "tracking recent records for all maps \n - probably more!\n\nThis is by far my largest coding project "   +
        "with hundreds of hours put in, so I hope you find it useful! " + Icons::SmileO + "\n\n"
    );

    UI::Separator();

    UI::TextWrapped(
        "Plugin files are kept at " + Storage::storageFolder +
        "\nIf you want to look in the database, I recommend DB Browser: sqlitebrowser.org\n"
    );

    UI::Separator();

    if (Storage::dev) {
        if (UI::Button("Lock Dev Tab")) {
            Various::Trace("dev tab locked");
            Storage::dev = false;
        }
    } else {
        if (UI::InputText("Unlock Dev Tab", "") == "balls") {
            Various::Trace("dev tab unlocked");
            Storage::dev = true;
        }
    }

    UI::EndTabItem();
}

void RenderDevTab() {
    if (!UI::BeginTabItem(Icons::Cogs + " Dev")) return;

    if (UI::Button(Icons::Download + " Get All Records"))
        startnew(CoroutineFunc(Maps::GetMyMapsRecordsCoro));

    UI::Text("total accounts: " + Storage::accounts.Length);
    UI::Text("account IDs: " + Storage::accountIds.GetKeys().Length);

    UI::EndTabItem();
}