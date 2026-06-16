#pragma once

#include <JuceHeader.h>

class ConnectionIndicator : public juce::Component {
public:
    void setIndicatorColour(juce::Colour colour) {
        if (colour_ != colour) {
            colour_ = colour;
            repaint();
        }
    }

    void paint(juce::Graphics& g) override {
        auto bounds = getLocalBounds().toFloat();
        const float diameter = juce::jmin(bounds.getWidth(), bounds.getHeight()) - 2.0f;
        auto circle = juce::Rectangle<float>(diameter, diameter).withCentre(bounds.getCentre());
        g.setColour(colour_);
        g.fillEllipse(circle);
        g.setColour(colour_.brighter(0.2f).withAlpha(0.5f));
        g.drawEllipse(circle.expanded(0.5f), 1.0f);
    }

private:
    juce::Colour colour_ = juce::Colours::indianred;
};
