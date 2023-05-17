/*
c 2023-05-16
m 2023-05-17
*/

namespace DB {
    namespace MyMaps {
        void LoadAll() {
            auto now = Time::Now;
            trace("loading my maps from " + Storage::dbFile);

            Storage::maps.RemoveRange(0, Storage::maps.Length);
            SQLite::Statement@ s;
            @Storage::db = SQLite::Database(Storage::dbFile);
            try {
                @s = Storage::db.Prepare("SELECT * FROM MyMaps");
            } catch {
                trace("no MyMaps table in database, plugin hasn't been run yet");
                if (Settings::printDurations)
                    trace("returning after " + (Time::Now - now) + " ms");
                return;
            }

            while (true) {
                if (!s.NextRow()) break;
                Storage::maps.InsertLast(Models::Map(s));
            }

            if (Settings::printDurations)
                trace("loading my maps took " + (Time::Now - now) + " ms");
        }

        void SaveAll() {
            auto now = Time::Now;
            trace("saving my maps to " + Storage::dbFile);

            Storage::db.Execute("""
                CREATE TABLE IF NOT EXISTS MyMaps (
                    authorId      CHAR(36),
                    authorTime    INT,
                    badUploadTime BOOL,
                    bronzeTime    INT,
                    downloadUrl   CHAR(93),
                    goldTime      INT,
                    mapId         CHAR(36),
                    mapNameColor  TEXT,
                    mapNameRaw    TEXT,
                    mapNameText   TEXT,
                    mapUid        VARCHAR(27) PRIMARY KEY,
                    silverTime    INT,
                    thumbnailUrl  CHAR(97),
                    timestamp     INT
                );
            """);

            for (uint i = 0; i < Storage::maps.Length; i++) {
                auto map = Storage::maps[i];
                SQLite::Statement@ s;
                @s = Storage::db.Prepare("""
                    INSERT INTO MyMaps (
                        authorId,
                        authorTime,
                        badUploadTime,
                        bronzeTime,
                        downloadUrl,
                        goldTime,
                        mapId,
                        mapNameColor,
                        mapNameRaw,
                        mapNameText,
                        mapUid,
                        silverTime,
                        thumbnailUrl,
                        timestamp
                    ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?);
                """);
                s.Bind(1,  map.authorId);
                s.Bind(2,  map.authorTime);
                s.Bind(3,  map.badUploadTime ? 1 : 0);
                s.Bind(4,  map.bronzeTime);
                s.Bind(5,  map.downloadUrl);
                s.Bind(6,  map.goldTime);
                s.Bind(7,  map.mapId);
                s.Bind(8,  map.mapNameColor);
                s.Bind(9,  map.mapNameRaw);
                s.Bind(10, map.mapNameText);
                s.Bind(11, map.mapUid);
                s.Bind(12, map.silverTime);
                s.Bind(13, map.thumbnailUrl);
                s.Bind(14, map.timestamp);
                s.Execute();
            }

            if (Settings::printDurations)
                trace("saving my maps took " + (Time::Now - now) + " ms");
        }
    }
}