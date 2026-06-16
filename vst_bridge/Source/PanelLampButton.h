#pragma once

#include <functional>

#include <JuceHeader.h>

enum class LampColour { Off, Green, Red };

class PanelLampButton : public juce::Component, public juce::SettableTooltipClient {
public:
    explicit PanelLampButton(juce::String buttonText = {}) : buttonText_(std::move(buttonText)) {}

    void setButtonText(const juce::String& text) {
        if (buttonText_ != text) {
            buttonText_ = text;
            repaint();
        }
    }

    void setLampColour(LampColour colour) {
        if (lampColour_ != colour) {
            lampColour_ = colour;
            repaint();
        }
    }

    void setToggleMode(bool toggleMode) { toggleMode_ = toggleMode; }

    void setToggled(bool on) {
        if (toggled_ != on) {
            toggled_ = on;
            repaint();
        }
    }

    bool getToggled() const { return toggled_; }

    std::function<void()> onClick;

    void paint(juce::Graphics& g) override {
        auto bounds = getLocalBounds().toFloat().reduced(0.5f);
        const bool enabled = isEnabled();
        const bool pressed = isMouseButtonDown() && enabled;

        if (pressed) {
            bounds = bounds.translated(0.0f, 0.5f);
        }

        const juce::Colour faceTop = enabled ? juce::Colour(0xff3d3d3d) : juce::Colour(0xff2e2e2e);
        const juce::Colour faceBottom = enabled ? juce::Colour(0xff1a1a1a) : juce::Colour(0xff242424);
        juce::ColourGradient gradient(faceTop, bounds.getX(), bounds.getY(), faceBottom, bounds.getX(),
                                      bounds.getBottom(), false);
        g.setGradientFill(gradient);
        g.fillRoundedRectangle(bounds, 4.0f);

        g.setColour(juce::Colours::white.withAlpha(enabled ? 0.14f : 0.06f));
        g.drawLine(bounds.getX() + 5.0f, bounds.getY() + 1.0f, bounds.getRight() - 5.0f, bounds.getY() + 1.0f, 1.0f);

        g.setColour(juce::Colours::black.withAlpha(enabled ? 0.55f : 0.25f));
        g.drawRoundedRectangle(bounds, 4.0f, 1.0f);

        paintLamp(g, bounds, enabled);

        g.setColour(enabled ? juce::Colours::lightgrey : juce::Colours::grey.withAlpha(0.55f));
        g.setFont(juce::FontOptions(13.0f));
        g.drawText(buttonText_, bounds.withTrimmedLeft(26.0f), juce::Justification::centred, true);
    }

    void mouseDown(const juce::MouseEvent&) override {
        if (isEnabled()) {
            repaint();
        }
    }

    void mouseUp(const juce::MouseEvent& event) override {
        repaint();
        if (!isEnabled() || !event.mouseWasClicked()) {
            return;
        }
        if (onClick) {
            onClick();
        }
    }

private:
    void paintLamp(juce::Graphics& g, juce::Rectangle<float> bounds, bool enabled) const {
        const float lampW = 5.0f;
        const float lampH = 14.0f;
        auto lampBounds =
            juce::Rectangle<float>(lampW, lampH).withCentre({bounds.getX() + 14.0f, bounds.getCentreY()});

        g.setColour(juce::Colours::black.withAlpha(enabled ? 0.65f : 0.35f));
        g.fillRoundedRectangle(lampBounds.expanded(1.0f), lampW * 0.55f);

        if (lampColour_ != LampColour::Off && enabled) {
            juce::Colour fill = juce::Colours::limegreen;
            if (lampColour_ == LampColour::Red) {
                fill = juce::Colour(0xffe04040);
            }
            auto lit = lampBounds.reduced(0.5f);
            g.setColour(fill.withAlpha(0.95f));
            g.fillRoundedRectangle(lit, lampW * 0.48f);
            g.setColour(fill.brighter(0.35f).withAlpha(0.75f));
            g.fillRoundedRectangle(lit.removeFromTop(lit.getHeight() * 0.35f), 1.5f);
        } else {
            g.setColour(enabled ? juce::Colour(0xff121212) : juce::Colour(0xff3a3a3a));
            g.fillRoundedRectangle(lampBounds.reduced(1.0f), lampW * 0.42f);
        }
    }

    juce::String buttonText_;
    LampColour lampColour_ = LampColour::Off;
    bool toggleMode_ = false;
    bool toggled_ = false;
};
