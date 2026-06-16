#pragma once

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <string>

enum class DeliveryQuality { Unknown, Smooth, Moderate, Bursty };

enum class NetworkProfile { Auto, Wsl, Local, Lan };

class DeliveryQualityMonitor {
public:
    static constexpr int kMaxIntervals = 512;
    static constexpr double kExpectedIntervalMs = 5.333; // 256 frames @ 48 kHz

    void reset() {
        intervalCount_ = 0;
        intervalWrite_ = 0;
        burstEvents_ = 0;
        samplesInWindow_ = 0;
        fillBelowMinEvents_ = 0;
        lastArrivalUs_ = 0;
        hasLastArrival_ = false;
        lastIntervalMs_ = 0.0;
        quality_ = DeliveryQuality::Unknown;
        smoothSinceUs_ = 0;
        hasSmoothSince_ = false;
    }

    void recordArrival(uint64_t nowUs) {
        if (hasLastArrival_) {
            const double dtMs = static_cast<double>(nowUs - lastArrivalUs_) / 1000.0;
            if (dtMs > 0.0 && dtMs < 500.0) {
                intervals_[static_cast<size_t>(intervalWrite_)] = dtMs;
                intervalWrite_ = (intervalWrite_ + 1) % kMaxIntervals;
                if (intervalCount_ < kMaxIntervals) {
                    ++intervalCount_;
                }

                if (lastIntervalMs_ < 2.0 && dtMs > 15.0) {
                    ++burstEvents_;
                }
                lastIntervalMs_ = dtMs;
            }
        }
        lastArrivalUs_ = nowUs;
        hasLastArrival_ = true;
        ++samplesInWindow_;
        recomputeQuality(nowUs);
    }

    void recordFillBelowMin() { ++fillBelowMinEvents_; }

    DeliveryQuality getQuality() const { return quality_; }

    double getP95JitterMs() const { return p95Ms_; }

    double getStdDevMs() const { return stdDevMs_; }

    double getBurstScorePercent() const {
        if (intervalCount_ <= 0) {
            return 0.0;
        }
        return 100.0 * static_cast<double>(burstEvents_) / static_cast<double>(intervalCount_);
    }

    bool canDecreaseReserve(uint64_t nowUs) const {
        if (quality_ != DeliveryQuality::Smooth) {
            return false;
        }
        if (!hasSmoothSince_) {
            return false;
        }
        return (nowUs - smoothSinceUs_) >= 30'000'000;
    }

    void tickWindow(uint64_t /*nowUs*/) {
        burstEvents_ = std::max(0, burstEvents_ - 1);
        fillBelowMinEvents_ = std::max(0, fillBelowMinEvents_ - 1);
        if (samplesInWindow_ > 0) {
            --samplesInWindow_;
        }
    }

private:
    void recomputeQuality(uint64_t nowUs) {
        if (intervalCount_ < 8) {
            quality_ = DeliveryQuality::Unknown;
            hasSmoothSince_ = false;
            return;
        }

        double sum = 0.0;
        for (int i = 0; i < intervalCount_; ++i) {
            sum += intervals_[static_cast<size_t>(i)];
        }
        const double mean = sum / static_cast<double>(intervalCount_);

        double varSum = 0.0;
        for (int i = 0; i < intervalCount_; ++i) {
            const double d = intervals_[static_cast<size_t>(i)] - mean;
            varSum += d * d;
        }
        stdDevMs_ = std::sqrt(varSum / static_cast<double>(intervalCount_));

        std::array<double, kMaxIntervals> sorted{};
        for (int i = 0; i < intervalCount_; ++i) {
            sorted[static_cast<size_t>(i)] = intervals_[static_cast<size_t>(i)];
        }
        std::sort(sorted.begin(), sorted.begin() + intervalCount_);
        const int p95Idx = std::min(intervalCount_ - 1, (intervalCount_ * 95) / 100);
        p95Ms_ = sorted[static_cast<size_t>(p95Idx)];

        const double burstScore = getBurstScorePercent();

        DeliveryQuality next = DeliveryQuality::Moderate;
        if (burstScore > 15.0 || p95Ms_ > 25.0 || fillBelowMinEvents_ >= 2) {
            next = DeliveryQuality::Bursty;
        } else if (stdDevMs_ < 2.0 && burstScore < 5.0 && fillBelowMinEvents_ == 0) {
            next = DeliveryQuality::Smooth;
        }

        if (next == DeliveryQuality::Smooth && quality_ != DeliveryQuality::Smooth) {
            smoothSinceUs_ = nowUs;
            hasSmoothSince_ = true;
        } else if (next != DeliveryQuality::Smooth) {
            hasSmoothSince_ = false;
        }
        quality_ = next;
    }

    std::array<double, kMaxIntervals> intervals_{};
    int intervalCount_ = 0;
    int intervalWrite_ = 0;
    int burstEvents_ = 0;
    int fillBelowMinEvents_ = 0;
    int samplesInWindow_ = 0;
    uint64_t lastArrivalUs_ = 0;
    bool hasLastArrival_ = false;
    double lastIntervalMs_ = 0.0;
    double stdDevMs_ = 0.0;
    double p95Ms_ = 0.0;
    DeliveryQuality quality_ = DeliveryQuality::Unknown;
    uint64_t smoothSinceUs_ = 0;
    bool hasSmoothSince_ = false;
};

inline bool hostIsLoopback(const std::string& host) {
    return host == "127.0.0.1" || host == "localhost" || host == "::1";
}

inline bool hostLooksLikeWsl(const std::string& host) {
    return host.size() >= 4 && host.compare(0, 4, "172.") == 0;
}

inline NetworkProfile inferNetworkProfile(const std::string& host) {
    if (hostIsLoopback(host)) {
        return NetworkProfile::Local;
    }
    if (hostLooksLikeWsl(host)) {
        return NetworkProfile::Wsl;
    }
    return NetworkProfile::Lan;
}

inline const char* networkProfileLabel(NetworkProfile profile) {
    switch (profile) {
    case NetworkProfile::Wsl:
        return "WSL";
    case NetworkProfile::Local:
        return "Local";
    case NetworkProfile::Lan:
        return "LAN";
    case NetworkProfile::Auto:
    default:
        return "Auto";
    }
}

inline void applyProfileDefaults(NetworkProfile profile,
                                 int& warmup,
                                 int& minReserve,
                                 int& target) {
    switch (profile) {
    case NetworkProfile::Local:
        warmup = 12;
        minReserve = 4;
        target = 8;
        break;
    case NetworkProfile::Lan:
        warmup = 16;
        minReserve = 8;
        target = 12;
        break;
    case NetworkProfile::Wsl:
        warmup = 20;
        minReserve = 10;
        target = 16;
        break;
    case NetworkProfile::Auto:
    default:
        warmup = 20;
        minReserve = 10;
        target = 16;
        break;
    }
}
