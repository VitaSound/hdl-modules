#pragma once

#include <JuceHeader.h>

class BufferLevelBar : public juce::Component, public juce::SettableTooltipClient {
public:
    void setLevels(int fillPackets, int targetPackets, int minPackets, double latencyMs) {
        fillPackets_ = juce::jmax(0, fillPackets);
        targetPackets_ = juce::jmax(1, targetPackets);
        minPackets_ = juce::jmax(0, minPackets);
        latencyMs_ = latencyMs;
        setTooltip(buildTooltipText());
        repaint();
    }

    void paint(juce::Graphics& g) override {
        auto bounds = getLocalBounds().toFloat().reduced(0.5f);
        g.setColour(juce::Colours::black.withAlpha(0.35f));
        g.fillRoundedRectangle(bounds, 3.0f);
        g.setColour(juce::Colours::white.withAlpha(0.15f));
        g.drawRoundedRectangle(bounds, 3.0f, 1.0f);

        const float scale = juce::jmin(1.0f, static_cast<float>(fillPackets_) / static_cast<float>(targetPackets_));
        auto fillBounds = bounds.withWidth(bounds.getWidth() * scale);

        juce::Colour fillColour = juce::Colours::limegreen;
        if (fillPackets_ < minPackets_) {
            fillColour = juce::Colours::indianred;
        } else if (fillPackets_ < targetPackets_) {
            fillColour = juce::Colours::orange;
        }
        g.setColour(fillColour.withAlpha(0.85f));
        g.fillRoundedRectangle(fillBounds, 3.0f);

        const float minX =
            bounds.getX() + bounds.getWidth() * static_cast<float>(minPackets_) / static_cast<float>(targetPackets_);
        g.setColour(juce::Colours::white.withAlpha(0.7f));
        g.drawLine(minX, bounds.getY() + 1.0f, minX, bounds.getBottom() - 1.0f, 1.5f);

        g.setColour(juce::Colours::white.withAlpha(0.55f));
        g.setFont(juce::FontOptions(10.0f));
        g.drawText(juce::String(fillPackets_) + " / " + juce::String(targetPackets_) + " pkt",
                   bounds.reduced(4.0f, 0.0f),
                   juce::Justification::centredLeft,
                   true);
    }

    juce::String buildTooltipText() const {
        return "Buffer: " + juce::String(fillPackets_) + "/" + juce::String(targetPackets_) + " pkt (~" +
               juce::String(latencyMs_, 0) + " ms)";
    }

private:
    int fillPackets_ = 0;
    int targetPackets_ = 1;
    int minPackets_ = 0;
    double latencyMs_ = 0.0;
};
