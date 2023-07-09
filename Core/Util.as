/*
c 2023-05-20
m 2023-07-09
*/

namespace Util {
    string FormatSeconds(int seconds) {
        int minutes = seconds / 60;
        seconds %= 60;
        int hours = minutes / 60;
        minutes %= 60;
        int days = hours / 24;
        hours %= 24;

        if (days > 0)
            return Zpad2(days) + ":" + Zpad2(hours) + ":" + Zpad2(minutes) + ":" + Zpad2(seconds);
        if (hours > 0)
            return "00:" + Zpad2(hours) + ":" + Zpad2(minutes) + ":" + Zpad2(seconds);
        if (minutes > 0)
            return "00:00:" + Zpad2(minutes) + ":" + Zpad2(seconds);
        return "00:00:00:" + Zpad2(seconds);
    }

    dictionary JsonLoadToDict(const string &in filename) {
        auto timer = LogTimerBegin("loading map order");
        Json::Value json;
        dictionary dict;

        try {
            json = Json::FromFile(filename);
        } catch {
            Warn("json file missing!");
            return dict;
        }

        for (uint i = 1; i <= json.Length; i++) {
            auto key = "" + i;
            auto val = json.Get(key);
            dict.Set(key, string(val));
        }
        LogTimerEnd(timer);
        return dict;
    }

    void JsonSaveFromDict(dictionary dict, const string &in filename) {
        auto timer = LogTimerBegin("saving json file");
        Json::ToFile(filename, dict.ToJson());
        LogTimerEnd(timer);
    }

    string LogTimerBegin(const string &in text, bool logNow = true) {
        if (logNow) Trace(text + "...");
        string timerId = Globals::logTimerIndex + "_LogTimer_" + text;
        Globals::logTimerIndex++;
        Globals::logTimers.Set(timerId, Time::Now);
        return timerId;
    }

    void LogTimerDelete(const string &in timerId) {
        try { Globals::logTimers.Delete(timerId); } catch { }
    }

    void LogTimerEnd(const string &in timerId, bool logNow = true) {
        if (Settings::logDurations && logNow) {
            string text = timerId.Split("_LogTimer_")[1];
            uint64 start;
            if (Globals::logTimers.Get(timerId, start)) {
                uint64 dur = Time::Now - start;
                if (dur == 0)
                    Trace(text + " took 0s");
                else
                    Trace(text + " took " + (dur / 1000) + "." + (dur % 1000) + "s");
            } else {
                Trace("timerId not found: " + timerId);
            }
        }
        LogTimerDelete(timerId);
    }

    string StrWrap(const string &in input, const string &in wrapper = "'") {
        return wrapper + input + wrapper;
    }

    void Trace(const string &in text) {
        if (!Settings::logEnabled) return;
        trace(text);
    }

    void WaitToDoNadeoRequestCoro() {
        if (Globals::latestNadeoRequest == 0) {
            Globals::latestNadeoRequest = Time::Now;
            return;
        }

        while (Globals::requesting)
            yield();
        Globals::requesting = true;

        while (Time::Now - Globals::latestNadeoRequest < Settings::timeBetweenNadeoRequests)
            yield();

        Globals::latestNadeoRequest = Time::Now;
    }

    void Warn(const string &in text) {
        if (!Settings::logEnabled) return;
        warn(text);
    }

    string Zpad2(int num) {
        if (num > 9) return "" + num;
        return "0" + num;
    }
}