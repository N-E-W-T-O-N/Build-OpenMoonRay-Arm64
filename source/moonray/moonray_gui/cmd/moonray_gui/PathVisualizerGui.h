// Copyright 2025 DreamWorks Animation LLC
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <QWidget>

class QGridLayout;
class QPushButton;
class QSpinBox;
class QLabel;

namespace moonray { namespace rndr { class PathVisualizerManager; }}

namespace moonray_gui {

class ColorPicker;
class RenderViewport;

class PathVisualizerGui : public QWidget
{
    Q_OBJECT

public:
    explicit PathVisualizerGui(QWidget* parent, moonray::rndr::PathVisualizerManager* manager);

    ~PathVisualizerGui();

public slots:

    void slot_togglePathVisualizer();

    void slot_processPixelXValue(const int x);
    void slot_processPixelYValue(const int y);
    void slot_processPixel(const int x, const int y);

    void slot_processMaxDepth(const int depth);

    void slot_processUseSceneSamples(const int useSceneSamples);
    void slot_processPixelSamples(const int samples);
    void slot_processLightSamples(const int samples);
    void slot_processBsdfSamples(const int samples);

    void slot_processDiffuseRayFlag(const int flag);
    void slot_processSpecularRayFlag(const int flag);
    void slot_processBsdfSampleFlag(const int flag);
    void slot_processLightSampleFlag(const int flag);

    void slot_setLineWidth(const int width);
    void slot_setDiffuseRayColor(const QColor& color);
    void slot_setSpecularRayColor(const QColor& color);
    void slot_setBsdfSampleColor(const QColor& color);
    void slot_setLightSampleColor(const QColor& color);
    void slot_setCameraRayColor(const QColor& color);

signals:
    void sig_styleParamChanged();

private:

    void setupOnBtn(QGridLayout* layout);
    void setupPixelUI(QGridLayout* layout);
    void setupSamplingUI(QGridLayout* layout);
    void setupDepthUI(QGridLayout* layout);
    void setupVisibilityUI(QGridLayout* layout);
    void setupStyleUI(QGridLayout* layout);

    moonray::rndr::PathVisualizerManager* mPathVisualizerManager;

    int mCurrentRow;

    QPushButton* mOnBtn;

    QSpinBox* mPixelXSpinBox;
    QSpinBox* mPixelYSpinBox;

    QSpinBox* mPixelSamples;
    QSpinBox* mLightSamples;
    QSpinBox* mBsdfSamples;

    QLabel* mLineWidthValue;

    ColorPicker* mDiffuseRayColorPicker;
    ColorPicker* mSpecularRayColorPicker;
    ColorPicker* mBsdfSampleColorPicker;
    ColorPicker* mLightSampleColorPicker;
    ColorPicker* mCameraRayColorPicker;
};

} // namespace moonray_gui
