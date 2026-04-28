"""
normalizer_app.py
=================
PyQt6 GUI for the Chameleon.
Matches the layout and workflow of the MATLAB version.

Run directly:
    python normalizer_app.py

Or via the launcher:
    python run_normalizer.py
"""

import sys
import os
import threading
from pathlib import Path

import numpy as np
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QLabel, QPushButton,
    QLineEdit, QListWidget, QComboBox, QCheckBox, QRadioButton,
    QButtonGroup, QFileDialog, QProgressBar, QFrame, QSplitter,
    QGroupBox, QScrollArea, QMessageBox, QSizePolicy
)
from PyQt6.QtCore import Qt, QThread, pyqtSignal, QObject, QTimer
from PyQt6.QtGui import QFont, QColor, QPalette, QPixmap, QImage, QFontDatabase

import matplotlib
matplotlib.use('QtAgg')
from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure
import matplotlib.pyplot as plt

from normalizer_core import (
    load_image, save_image, find_images,
    compute_image_cdf, compute_batch_average_cdf,
    compute_reinhard_stats, compute_batch_average_reinhard_stats,
    apply_histogram_match, apply_reinhard,
    run_histogram_batch, run_reinhard_batch, write_csv_log
)

# ── Colour palette ─────────────────────────────────────────────────────────
BG       = '#141921'
PANEL    = '#1e2530'
PANEL2   = '#171e28'
ACCENT   = '#2f85cc'
ACCENT2  = '#38b38d'
TEXT     = '#ebecf2'
DIM      = '#8c96ad'
WARNING  = '#f2a533'
SUCCESS  = '#40c77a'
DANGER   = '#e65555'
BORDER   = '#2a3344'


def style_sheet() -> str:
    return f"""
    QMainWindow, QWidget {{
        background-color: {BG};
        color: {TEXT};
        font-family: 'Segoe UI', 'SF Pro Display', sans-serif;
        font-size: 11px;
    }}
    QGroupBox {{
        border: 1px solid {BORDER};
        border-radius: 6px;
        margin-top: 10px;
        padding-top: 8px;
        font-size: 10px;
        font-weight: bold;
        color: {DIM};
        letter-spacing: 1px;
    }}
    QGroupBox::title {{
        subcontrol-origin: margin;
        left: 8px;
        padding: 0 4px;
    }}
    QLineEdit {{
        background-color: {PANEL2};
        border: 1px solid {BORDER};
        border-radius: 4px;
        padding: 4px 8px;
        color: {TEXT};
        font-size: 11px;
    }}
    QLineEdit:focus {{
        border-color: {ACCENT};
    }}
    QPushButton {{
        background-color: {PANEL};
        border: 1px solid {BORDER};
        border-radius: 5px;
        padding: 5px 12px;
        color: {TEXT};
        font-size: 11px;
    }}
    QPushButton:hover {{
        background-color: #2a3344;
        border-color: {ACCENT};
    }}
    QPushButton:pressed {{
        background-color: {PANEL2};
    }}
    QPushButton:disabled {{
        color: {DIM};
        border-color: {BORDER};
    }}
    QPushButton#run_btn {{
        background-color: {ACCENT};
        border: none;
        font-size: 13px;
        font-weight: bold;
        color: white;
        padding: 10px;
        border-radius: 6px;
    }}
    QPushButton#run_btn:hover {{
        background-color: #3a95dc;
    }}
    QPushButton#cancel_btn {{
        background-color: {DANGER};
        border: none;
        font-size: 13px;
        color: white;
        padding: 10px;
        border-radius: 6px;
    }}
    QPushButton#preview_btn {{
        background-color: #162a1e;
        border: 1px solid #2a5a3a;
        font-size: 11px;
        font-weight: bold;
        color: {ACCENT2};
        padding: 8px;
        border-radius: 6px;
    }}
    QPushButton#preview_btn:hover {{
        background-color: #1e3a28;
    }}
    QPushButton#apply_btn {{
        background-color: #162a1e;
        border: 1px solid #2a5a3a;
        font-weight: bold;
        color: {ACCENT2};
        padding: 6px 14px;
        border-radius: 5px;
    }}
    QPushButton#close_btn {{
        background-color: #2a1212;
        border: 1px solid #5a2222;
        color: #ff8888;
        padding: 5px 12px;
        border-radius: 5px;
    }}
    QListWidget {{
        background-color: {PANEL2};
        border: 1px solid {BORDER};
        border-radius: 4px;
        color: {TEXT};
        font-size: 10px;
    }}
    QListWidget::item:selected {{
        background-color: {ACCENT};
        color: white;
    }}
    QComboBox {{
        background-color: {PANEL2};
        border: 1px solid {BORDER};
        border-radius: 4px;
        padding: 4px 24px 4px 8px;
        color: {TEXT};
        font-size: 11px;
        min-width: 80px;
    }}
    QComboBox::drop-down {{
        border: none;
        width: 24px;
    }}
    QComboBox::down-arrow {{
        image: none;
        width: 0;
        height: 0;
        border-left: 5px solid transparent;
        border-right: 5px solid transparent;
        border-top: 6px solid {DIM};
    }}
    QComboBox QAbstractItemView {{
        background-color: {PANEL};
        border: 1px solid {BORDER};
        color: {TEXT};
        selection-background-color: {ACCENT};
    }}
    QRadioButton {{
        color: {TEXT};
        font-size: 11px;
        spacing: 8px;
    }}
    QRadioButton::indicator {{
        width: 14px;
        height: 14px;
        border-radius: 7px;
        border: 2px solid {DIM};
        background-color: {PANEL2};
    }}
    QRadioButton::indicator:checked {{
        background-color: {ACCENT};
        border-color: {ACCENT};
    }}
    QCheckBox {{
        color: {TEXT};
        font-size: 11px;
        spacing: 8px;
    }}
    QCheckBox::indicator {{
        width: 14px;
        height: 14px;
        border-radius: 3px;
        border: 2px solid {DIM};
        background-color: {PANEL2};
    }}
    QCheckBox::indicator:checked {{
        background-color: {ACCENT};
        border-color: {ACCENT};
    }}
    QProgressBar {{
        background-color: {PANEL2};
        border: 1px solid {BORDER};
        border-radius: 4px;
        height: 8px;
        text-align: center;
        color: transparent;
    }}
    QProgressBar::chunk {{
        background-color: {ACCENT};
        border-radius: 3px;
    }}
    QLabel#title_lbl {{
        font-size: 20px;
        font-weight: bold;
        color: {ACCENT};
    }}
    QLabel#subtitle_lbl {{
        font-size: 10px;
        color: {DIM};
    }}
    QLabel#section_lbl {{
        font-size: 9px;
        font-weight: bold;
        color: {DIM};
        letter-spacing: 1px;
    }}
    QLabel#status_lbl {{
        font-size: 10px;
        color: {DIM};
        padding: 0 10px;
    }}
    QLabel#insp_title_lbl {{
        font-size: 13px;
        font-weight: bold;
        color: {ACCENT2};
    }}
    QFrame#separator {{
        background-color: {BORDER};
        max-height: 1px;
    }}
    QFrame#status_bar {{
        background-color: #0d1117;
        max-height: 28px;
        min-height: 28px;
    }}
    """


# ── Image display widget ───────────────────────────────────────────────────

class ImageCanvas(FigureCanvas):
    """Matplotlib canvas for displaying images with dark background."""

    def __init__(self, parent=None, title='', title_color=DIM):
        self.fig = Figure(facecolor=BG, tight_layout=True)
        self.ax  = self.fig.add_subplot(111)
        super().__init__(self.fig)
        self.setParent(parent)
        self._title       = title
        self._title_color = title_color
        self._style_ax()

    def _style_ax(self):
        self.ax.set_facecolor(BG)
        self.ax.set_xticks([])
        self.ax.set_yticks([])
        for spine in self.ax.spines.values():
            spine.set_edgecolor(BORDER)
        if self._title:
            self.ax.set_title(self._title, color=self._title_color,
                              fontsize=9, pad=4)
        self.fig.patch.set_facecolor(BG)

    def show_image(self, img: np.ndarray, title: str = None,
                   title_color: str = None):
        self.ax.clear()
        self._style_ax()
        if title:
            self.ax.set_title(title, color=title_color or self._title_color,
                              fontsize=9, pad=4)
        if img is not None:
            self.ax.imshow(img)
        self.draw()

    def show_placeholder(self, message: str, title: str = None):
        self.ax.clear()
        self._style_ax()
        if title:
            self.ax.set_title(title, color=DIM, fontsize=9, pad=4)
        self.ax.text(0.5, 0.5, message, transform=self.ax.transAxes,
                     ha='center', va='center', color=DIM, fontsize=9)
        self.draw()

    def clear(self):
        self.ax.clear()
        self._style_ax()
        self.draw()


class HistCanvas(FigureCanvas):
    """Matplotlib canvas for RGB histogram overlays."""

    def __init__(self, parent=None, title=''):
        self.fig = Figure(facecolor=BG, tight_layout=True)
        self.ax  = self.fig.add_subplot(111)
        super().__init__(self.fig)
        self.setParent(parent)
        self._title = title
        self._style_ax()

    def _style_ax(self):
        self.ax.set_facecolor(BG)
        self.ax.tick_params(colors=DIM, labelsize=6)
        for spine in self.ax.spines.values():
            spine.set_edgecolor(BORDER)
        self.ax.set_xlim(0, 64)
        self.ax.set_ylim(0, 1)
        if self._title:
            self.ax.set_title(self._title, color=DIM, fontsize=8, pad=3)
        self.fig.patch.set_facecolor(BG)

    def plot_histogram(self, img: np.ndarray, title: str = None):
        self.ax.clear()
        self._style_ax()
        if title:
            self.ax.set_title(title, color=DIM, fontsize=8, pad=3)
        if img is not None:
            colors = ['#dd4444', '#44aa44', '#4466dd']
            for ch, col in enumerate(colors):
                h, _ = np.histogram(img[:, :, ch].ravel(), bins=64,
                                    range=(0, 255))
                h = h / (h.max() + 1e-9)
                self.ax.plot(h, color=col, linewidth=1.2, alpha=0.85)
        self.draw()

    def clear(self):
        self.ax.clear()
        self._style_ax()
        self.draw()


# ── Worker thread ─────────────────────────────────────────────────────────

class WorkerSignals(QObject):
    progress  = pyqtSignal(int, int, str)   # current, total, message
    preview   = pyqtSignal(object, object)  # orig_img, norm_img
    finished  = pyqtSignal(str)             # completion message
    error     = pyqtSignal(str)


class NormWorker(QThread):
    def __init__(self, mode, image_paths, output_dir, fmt,
                 save_log, ref_path=None, n_workers=4):
        super().__init__()
        self.mode        = mode
        self.image_paths = image_paths
        self.output_dir  = output_dir
        self.fmt         = fmt
        self.save_log    = save_log
        self.ref_path    = ref_path
        self.n_workers   = n_workers
        self._cancel     = False
        self.signals     = WorkerSignals()

    def cancel(self):
        self._cancel = True

    def run(self):
        try:
            n = len(self.image_paths)

            def progress(i, total, msg=''):
                self.signals.progress.emit(i, total, msg)

            def cancel_flag():
                return self._cancel

            # Build target
            if self.mode == 1:
                ref = load_image(self.ref_path)
                target = compute_image_cdf(ref)
            elif self.mode == 2:
                def prog2(i, t, m=''): progress(i, t, f'Analysing batch {i}/{t}…')
                target = compute_batch_average_cdf(
                    self.image_paths, prog2, n_workers=self.n_workers)
            elif self.mode == 3:
                ref    = load_image(self.ref_path)
                target = compute_reinhard_stats(ref)
            else:  # mode 4
                def prog4(i, t, m=''): progress(i, t, f'Analysing batch {i}/{t}…')
                target = compute_batch_average_reinhard_stats(
                    self.image_paths, prog4, n_workers=self.n_workers)

            # Run batch
            if self.mode in (1, 2):
                log = run_histogram_batch(
                    self.image_paths, target, self.output_dir, self.fmt,
                    progress_cb=lambda i, t, m='': progress(i, t, m),
                    cancel_flag=cancel_flag,
                    n_workers=self.n_workers)
            else:
                log = run_reinhard_batch(
                    self.image_paths, target, self.output_dir, self.fmt,
                    progress_cb=lambda i, t, m='': progress(i, t, m),
                    cancel_flag=cancel_flag,
                    n_workers=self.n_workers)

            if self.save_log and log:
                mode_names = {1: 'HistMatch-Reference', 2: 'HistMatch-BatchAvg',
                              3: 'Reinhard-Reference',  4: 'Reinhard-BatchAvg'}
                write_csv_log(log, self.output_dir, mode_names[self.mode])

            if self._cancel:
                self.signals.finished.emit('Cancelled by user.')
            else:
                self.signals.finished.emit(
                    f'{n} images normalised → {self.output_dir}')

        except Exception as e:
            self.signals.error.emit(str(e))


# ── Inspector window ───────────────────────────────────────────────────────

class InspectorWindow(QWidget):
    method_chosen = pyqtSignal(int)  # emits mode index 1-4

    def __init__(self, image_paths, ref_path, parent=None):
        super().__init__(parent)
        self.image_paths = image_paths
        self.ref_path    = ref_path
        self.idx         = 0
        self._worker     = None

        self.setWindowTitle('Pre-flight Inspector')
        self.setMinimumSize(1200, 780)
        self.setStyleSheet(style_sheet())
        self._build_ui()
        self._load_index(0)

    def _build_ui(self):
        root = QWidget(self)
        root.setStyleSheet(f'background-color: {BG};')
        layout = self._vbox(root)
        self.setLayout(self._vbox())
        self.layout().addWidget(root)

        # ── Top bar ───────────────────────────────────────────────────
        top = QWidget()
        top.setFixedHeight(44)
        top.setStyleSheet(f'background-color: {PANEL}; border-bottom: 1px solid {BORDER};')
        tl = self._hbox(top)

        title = QLabel('PRE-FLIGHT INSPECTOR')
        title.setObjectName('insp_title_lbl')
        tl.addWidget(title)
        tl.addSpacing(16)

        self.img_label = QLabel('–')
        self.img_label.setStyleSheet(f'color: {DIM}; font-size: 10px;')
        tl.addWidget(self.img_label)
        tl.addStretch()

        self.close_btn = QPushButton('✕  Close')
        self.close_btn.setObjectName('close_btn')
        self.close_btn.setFixedWidth(100)
        self.close_btn.clicked.connect(self.close)
        tl.addWidget(self.close_btn)

        layout.addWidget(top)

        # ── Nav bar ───────────────────────────────────────────────────
        nav = QWidget()
        nav.setFixedHeight(48)
        nav.setStyleSheet(f'background-color: {PANEL2}; border-bottom: 1px solid {BORDER};')
        nl = self._hbox(nav)
        nl.setContentsMargins(12, 0, 12, 0)

        self.prev_btn = QPushButton('◀  Previous')
        self.prev_btn.setFixedWidth(110)
        self.prev_btn.clicked.connect(self._prev)
        nl.addWidget(self.prev_btn)

        self.next_btn = QPushButton('Next  ▶')
        self.next_btn.setFixedWidth(110)
        self.next_btn.clicked.connect(self._next)
        nl.addWidget(self.next_btn)

        nl.addSpacing(20)
        method_lbl = QLabel('Select method:')
        method_lbl.setStyleSheet(f'color: {TEXT};')
        nl.addWidget(method_lbl)

        self.method_dd = QComboBox()
        self.method_dd.addItems([
            'Mode 1 – Hist Match, Reference',
            'Mode 2 – Hist Match, Batch Avg',
            'Mode 3 – Reinhard, Reference',
            'Mode 4 – Reinhard, Batch Avg',
        ])
        self.method_dd.setCurrentIndex(1)
        self.method_dd.setFixedWidth(260)
        nl.addWidget(self.method_dd)

        nl.addSpacing(12)
        self.apply_btn = QPushButton('✔  Apply & Close')
        self.apply_btn.setObjectName('apply_btn')
        self.apply_btn.setFixedWidth(160)
        self.apply_btn.clicked.connect(self._apply)
        nl.addWidget(self.apply_btn)

        nl.addStretch()
        self.status_lbl = QLabel('–')
        self.status_lbl.setStyleSheet(f'color: {DIM}; font-size: 10px;')
        nl.addWidget(self.status_lbl)

        layout.addWidget(nav)

        # ── Image area ────────────────────────────────────────────────
        img_area = QWidget()
        img_layout = self._hbox(img_area)
        img_layout.setContentsMargins(8, 8, 8, 8)
        img_layout.setSpacing(8)

        # Left: original (narrow)
        orig_col = QWidget()
        orig_col.setFixedWidth(220)
        orig_vl = self._vbox(orig_col)
        orig_vl.setSpacing(2)

        orig_lbl = QLabel('ORIGINAL')
        orig_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        orig_lbl.setStyleSheet(f'color: {DIM}; font-size: 9px; font-weight: bold;')
        orig_vl.addWidget(orig_lbl)

        self.canvas_orig = ImageCanvas(title_color=DIM)
        self.canvas_orig.setSizePolicy(QSizePolicy.Policy.Expanding,
                                        QSizePolicy.Policy.Expanding)
        orig_vl.addWidget(self.canvas_orig)

        img_layout.addWidget(orig_col)

        # Right: 2×2 grid
        grid = QWidget()
        grid_layout = self._grid(grid)
        grid_layout.setSpacing(8)

        labels = [
            ('MODE 1 – Hist Match, Reference',  ACCENT,  0, 0),
            ('MODE 2 – Hist Match, Batch Avg',  ACCENT,  0, 1),
            ('MODE 3 – Reinhard, Reference',    ACCENT2, 1, 0),
            ('MODE 4 – Reinhard, Batch Avg',    ACCENT2, 1, 1),
        ]
        self.canvases = []
        for text, col, row, c in labels:
            cell = QWidget()
            cell_vl = self._vbox(cell)
            cell_vl.setSpacing(2)

            lbl = QLabel(text)
            lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
            lbl.setStyleSheet(f'color: {col}; font-size: 9px; font-weight: bold;')
            cell_vl.addWidget(lbl)

            canvas = ImageCanvas(title_color=col)
            canvas.setSizePolicy(QSizePolicy.Policy.Expanding,
                                  QSizePolicy.Policy.Expanding)
            cell_vl.addWidget(canvas)
            self.canvases.append(canvas)
            grid_layout.addWidget(cell, row, c)

        img_layout.addWidget(grid)
        layout.addWidget(img_area)

    def _load_index(self, idx):
        n = len(self.image_paths)
        self.idx = idx
        self.img_label.setText(
            f'Image {idx + 1} of {n}  —  {Path(self.image_paths[idx]).name}')
        self.prev_btn.setEnabled(idx > 0)
        self.next_btn.setEnabled(idx < n - 1)
        self.status_lbl.setText('Computing normalizations…')
        QApplication.processEvents()

        try:
            img = load_image(self.image_paths[idx])
        except Exception as e:
            self.status_lbl.setText(f'Error: {e}')
            return

        self.canvas_orig.show_image(img, 'Original', DIM)

        # Clear grid canvases
        for cv in self.canvases:
            cv.clear()
        QApplication.processEvents()

        # Mode 2: hist match batch avg
        self.status_lbl.setText('Computing batch-average histogram (Mode 2)…')
        QApplication.processEvents()
        try:
            cdf = compute_batch_average_cdf(self.image_paths)
            m2  = apply_histogram_match(img, cdf)
            self.canvases[1].show_image(m2)
        except Exception as e:
            self.canvases[1].show_placeholder(f'Error: {e}')
        QApplication.processEvents()

        # Mode 4: Reinhard batch avg
        self.status_lbl.setText('Computing batch-average Reinhard (Mode 4)…')
        QApplication.processEvents()
        try:
            stats = compute_batch_average_reinhard_stats(self.image_paths)
            m4    = apply_reinhard(img, stats)
            self.canvases[3].show_image(m4)
        except Exception as e:
            self.canvases[3].show_placeholder(f'Error: {e}')
        QApplication.processEvents()

        # Modes 1 & 3: reference-based
        if self.ref_path and Path(self.ref_path).is_file():
            self.status_lbl.setText('Computing reference-based methods (Modes 1 & 3)…')
            QApplication.processEvents()
            try:
                ref      = load_image(self.ref_path)
                ref_cdf  = compute_image_cdf(ref)
                ref_stat = compute_reinhard_stats(ref)

                m1 = apply_histogram_match(img, ref_cdf)
                self.canvases[0].show_image(m1)

                m3 = apply_reinhard(img, ref_stat)
                self.canvases[2].show_image(m3)
            except Exception as e:
                self.canvases[0].show_placeholder(f'Error: {e}')
                self.canvases[2].show_placeholder(f'Error: {e}')
        else:
            self.canvases[0].show_placeholder('No reference image set\n(browse to enable)')
            self.canvases[2].show_placeholder('No reference image set\n(browse to enable)')

        self.status_lbl.setText(
            f'Image {idx + 1} of {n}  —  use ◀ ▶ to step through batch')

    def _prev(self):
        if self.idx > 0:
            self._load_index(self.idx - 1)

    def _next(self):
        if self.idx < len(self.image_paths) - 1:
            self._load_index(self.idx + 1)

    def _apply(self):
        mode = self.method_dd.currentIndex() + 1  # 1-based
        self.method_chosen.emit(mode)
        self.close()

    # ── Layout helpers ─────────────────────────────────────────────────
    @staticmethod
    def _vbox(widget=None):
        from PyQt6.QtWidgets import QVBoxLayout
        layout = QVBoxLayout()
        layout.setContentsMargins(0, 0, 0, 0)
        if widget:
            widget.setLayout(layout)
        return layout

    @staticmethod
    def _hbox(widget=None):
        from PyQt6.QtWidgets import QHBoxLayout
        layout = QHBoxLayout()
        layout.setContentsMargins(8, 0, 8, 0)
        layout.setSpacing(6)
        if widget:
            widget.setLayout(layout)
        return layout

    @staticmethod
    def _grid(widget=None):
        from PyQt6.QtWidgets import QGridLayout
        layout = QGridLayout()
        layout.setContentsMargins(0, 0, 0, 0)
        if widget:
            widget.setLayout(layout)
        return layout


# ── Main window ────────────────────────────────────────────────────────────

class MainWindow(QMainWindow):

    def __init__(self):
        super().__init__()
        self.setWindowTitle('Chameleon  v1.0')
        self.setMinimumSize(1280, 820)
        self.setStyleSheet(style_sheet())

        self._image_paths = []
        self._worker      = None
        self._inspector   = None

        self._build_ui()

    # ── UI construction ───────────────────────────────────────────────

    def _build_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        root_vl = self._vbox(central)
        root_vl.setSpacing(0)
        root_vl.setContentsMargins(0, 0, 0, 0)

        # Header
        root_vl.addWidget(self._make_header())

        # Body
        body = QSplitter(Qt.Orientation.Horizontal)
        body.setHandleWidth(2)
        body.setStyleSheet(f'QSplitter::handle {{ background-color: {BORDER}; }}')
        body.addWidget(self._make_left_panel())
        body.addWidget(self._make_right_panel())
        body.setSizes([420, 860])
        root_vl.addWidget(body)

        # Status bar
        root_vl.addWidget(self._make_status_bar())

    def _make_header(self):
        header = QFrame()
        header.setFixedHeight(70)
        header.setStyleSheet(f'background-color: {PANEL}; border-bottom: 1px solid {BORDER};')
        hl = self._hbox(header)
        hl.setContentsMargins(20, 0, 20, 0)

        vl = self._vbox()
        title = QLabel('Chameleon')
        title.setObjectName('title_lbl')
        sub = QLabel('Four-mode histogram & Reinhard normalization  |  Pre-flight inspector for H&E / IHC brightfield images')
        sub.setObjectName('subtitle_lbl')
        vl.addWidget(title)
        vl.addWidget(sub)
        hl.addLayout(vl)
        hl.addStretch()
        return header

    def _make_status_bar(self):
        bar = QFrame()
        bar.setObjectName('status_bar')
        bar.setStyleSheet(f'background-color: #0d1117; border-top: 1px solid {BORDER};')
        bl = self._hbox(bar)
        self.status_lbl = QLabel('Ready  –  select a mode and load images to begin.')
        self.status_lbl.setObjectName('status_lbl')
        bl.addWidget(self.status_lbl)
        return bar

    def _make_left_panel(self):
        # Outer container — fixed width, holds the scroll area
        outer = QWidget()
        outer.setFixedWidth(420)
        outer.setStyleSheet(f'background-color: {PANEL};')
        outer_vl = self._vbox(outer)
        outer_vl.setContentsMargins(0, 0, 0, 0)
        outer_vl.setSpacing(0)

        # Scroll area so content never gets squashed
        from PyQt6.QtWidgets import QScrollArea
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setStyleSheet(f'background-color: {PANEL}; border: none;')

        panel = QWidget()
        panel.setStyleSheet(f'background-color: {PANEL};')
        vl = self._vbox(panel)
        vl.setContentsMargins(12, 12, 12, 12)
        vl.setSpacing(10)

        # ── Mode selection ────────────────────────────────────────────
        mode_group = QGroupBox('NORMALISATION MODE')
        mg_vl = self._vbox(mode_group)
        mg_vl.setSpacing(6)
        mg_vl.setContentsMargins(10, 14, 10, 10)

        self.mode_group = QButtonGroup()
        mode_texts = [
            '1 – Histogram matching  →  reference image',
            '2 – Histogram matching  →  batch-average CDF',
            '3 – Reinhard  →  reference image',
            '4 – Reinhard  →  batch-average synthetic reference',
        ]
        self.mode_radios = []
        for i, text in enumerate(mode_texts):
            rb = QRadioButton(text)
            if i == 0:
                rb.setChecked(True)
            self.mode_group.addButton(rb, i + 1)
            mg_vl.addWidget(rb)
            self.mode_radios.append(rb)
        self.mode_group.buttonToggled.connect(self._on_mode_changed)

        # Description box
        self.mode_desc = QLabel()
        self.mode_desc.setWordWrap(True)
        self.mode_desc.setStyleSheet(
            f'background-color: {PANEL2}; border: 1px solid {BORDER}; '
            f'border-radius: 4px; padding: 6px; color: {DIM}; font-size: 10px;')
        self.mode_desc.setFixedHeight(52)
        mg_vl.addWidget(self.mode_desc)

        vl.addWidget(mode_group)

        # ── Input folder ──────────────────────────────────────────────
        input_group = QGroupBox('INPUT FOLDER')
        ig_vl = self._vbox(input_group)
        ig_vl.setContentsMargins(10, 14, 10, 10)
        ig_hl = self._hbox()
        self.input_field = QLineEdit()
        self.input_field.setPlaceholderText('Select input folder…')
        browse_input = QPushButton('…')
        browse_input.setFixedWidth(36)
        browse_input.clicked.connect(self._browse_input)
        ig_hl.addWidget(self.input_field)
        ig_hl.addWidget(browse_input)
        ig_vl.addLayout(ig_hl)
        vl.addWidget(input_group)

        # ── Reference image ───────────────────────────────────────────
        self.ref_group = QGroupBox('REFERENCE IMAGE  (modes 1 & 3 only)')
        rg_vl = self._vbox(self.ref_group)
        rg_vl.setContentsMargins(10, 14, 10, 10)
        rg_hl = self._hbox()
        self.ref_field = QLineEdit()
        self.ref_field.setPlaceholderText('Select a reference image…')
        browse_ref = QPushButton('…')
        browse_ref.setFixedWidth(36)
        browse_ref.clicked.connect(self._browse_ref)
        rg_hl.addWidget(self.ref_field)
        rg_hl.addWidget(browse_ref)
        rg_vl.addLayout(rg_hl)
        vl.addWidget(self.ref_group)

        # ── Output folder ─────────────────────────────────────────────
        output_group = QGroupBox('OUTPUT FOLDER')
        og_vl = self._vbox(output_group)
        og_vl.setContentsMargins(10, 14, 10, 10)
        og_hl = self._hbox()
        self.output_field = QLineEdit()
        self.output_field.setPlaceholderText('Select output folder…')
        browse_output = QPushButton('…')
        browse_output.setFixedWidth(36)
        browse_output.clicked.connect(self._browse_output)
        og_hl.addWidget(self.output_field)
        og_hl.addWidget(browse_output)
        og_vl.addLayout(og_hl)
        vl.addWidget(output_group)

        # ── Options ───────────────────────────────────────────────────
        opt_group = QGroupBox('OUTPUT OPTIONS')
        opt_vl = self._vbox(opt_group)
        opt_vl.setContentsMargins(10, 14, 10, 10)
        opt_vl.setSpacing(8)

        # File format — in its own inner box
        fmt_box = QGroupBox('Output File Format')
        fmt_box.setStyleSheet(
            f'QGroupBox {{ border: 1px solid {BORDER}; border-radius: 4px; '
            f'margin-top: 8px; padding-top: 6px; font-size: 9px; color: {DIM}; }} '
            f'QGroupBox::title {{ subcontrol-origin: margin; left: 6px; padding: 0 4px; }}')
        fmt_box_hl = self._hbox(fmt_box)
        fmt_box_hl.setContentsMargins(8, 8, 8, 8)
        fmt_lbl = QLabel('Format:')
        fmt_lbl.setStyleSheet(f'color: {TEXT};')
        self.fmt_combo = QComboBox()
        self.fmt_combo.addItems(['tif', 'jpg', 'bmp'])
        self.fmt_combo.setFixedWidth(90)
        fmt_hint = QLabel('TIF recommended for lossless output')
        fmt_hint.setStyleSheet(f'color: {DIM}; font-size: 9px;')
        fmt_box_hl.addWidget(fmt_lbl)
        fmt_box_hl.addWidget(self.fmt_combo)
        fmt_box_hl.addSpacing(8)
        fmt_box_hl.addWidget(fmt_hint)
        fmt_box_hl.addStretch()
        opt_vl.addWidget(fmt_box)

        # Parallel workers — in its own inner box
        import os as _os
        cpu_count = _os.cpu_count() or 4
        workers_box = QGroupBox('Parallel Workers')
        workers_box.setStyleSheet(
            f'QGroupBox {{ border: 1px solid {BORDER}; border-radius: 4px; '
            f'margin-top: 8px; padding-top: 6px; font-size: 9px; color: {DIM}; }} '
            f'QGroupBox::title {{ subcontrol-origin: margin; left: 6px; padding: 0 4px; }}')
        workers_box_hl = self._hbox(workers_box)
        workers_box_hl.setContentsMargins(8, 8, 8, 8)
        workers_lbl = QLabel('Workers:')
        workers_lbl.setStyleSheet(f'color: {TEXT};')
        self.workers_combo = QComboBox()
        for w in [1, 2, 4, 8]:
            if w <= cpu_count:
                self.workers_combo.addItem(str(w))
        self.workers_combo.setFixedWidth(60)
        default_workers = max(2, cpu_count // 2)
        default_idx = self.workers_combo.findText(str(default_workers))
        if default_idx >= 0:
            self.workers_combo.setCurrentIndex(default_idx)
        cpu_lbl = QLabel(f'CPU cores available: {cpu_count}')
        cpu_lbl.setStyleSheet(f'color: {DIM}; font-size: 9px;')
        workers_box_hl.addWidget(workers_lbl)
        workers_box_hl.addWidget(self.workers_combo)
        workers_box_hl.addSpacing(8)
        workers_box_hl.addWidget(cpu_lbl)
        workers_box_hl.addStretch()
        opt_vl.addWidget(workers_box)

        self.log_check = QCheckBox('Save CSV normalization log')
        self.log_check.setChecked(True)
        opt_vl.addWidget(self.log_check)

        self.preview_check = QCheckBox('Show live preview during run')
        self.preview_check.setChecked(True)
        opt_vl.addWidget(self.preview_check)

        vl.addWidget(opt_group)

        # ── Image queue ───────────────────────────────────────────────
        queue_group = QGroupBox('IMAGE QUEUE')
        qg_vl = self._vbox(queue_group)
        qg_vl.setContentsMargins(10, 14, 10, 10)
        qg_vl.setSpacing(6)

        q_btns = self._hbox()
        reload_btn = QPushButton('Reload')
        reload_btn.setFixedWidth(70)
        reload_btn.clicked.connect(self._reload_files)
        clear_btn = QPushButton('Clear')
        clear_btn.setFixedWidth(60)
        clear_btn.clicked.connect(self._clear_files)
        self.count_lbl = QLabel('0 images loaded')
        self.count_lbl.setStyleSheet(f'color: {DIM}; font-size: 10px;')
        q_btns.addWidget(reload_btn)
        q_btns.addWidget(clear_btn)
        q_btns.addStretch()
        q_btns.addWidget(self.count_lbl)
        qg_vl.addLayout(q_btns)

        self.file_list = QListWidget()
        self.file_list.setMinimumHeight(80)
        qg_vl.addWidget(self.file_list)

        vl.addWidget(queue_group)
        vl.addStretch()

        # ── Progress ──────────────────────────────────────────────────
        self.progress_lbl = QLabel('Idle')
        self.progress_lbl.setStyleSheet(f'color: {DIM}; font-size: 10px;')
        vl.addWidget(self.progress_lbl)

        self.progress_bar = QProgressBar()
        self.progress_bar.setFixedHeight(6)
        self.progress_bar.setTextVisible(False)
        vl.addWidget(self.progress_bar)

        # ── Buttons ───────────────────────────────────────────────────
        self.preview_btn = QPushButton('🔍  Preview All Methods Before Running')
        self.preview_btn.setObjectName('preview_btn')
        self.preview_btn.setFixedHeight(34)
        self.preview_btn.clicked.connect(self._open_inspector)
        vl.addWidget(self.preview_btn)

        btn_row = self._hbox()
        self.run_btn = QPushButton('▶  Run Normalization')
        self.run_btn.setObjectName('run_btn')
        self.run_btn.setFixedHeight(42)
        self.run_btn.clicked.connect(self._run)

        self.cancel_btn = QPushButton('✕  Cancel')
        self.cancel_btn.setObjectName('cancel_btn')
        self.cancel_btn.setFixedHeight(42)
        self.cancel_btn.setEnabled(False)
        self.cancel_btn.clicked.connect(self._cancel)

        btn_row.addWidget(self.run_btn)
        btn_row.addWidget(self.cancel_btn)
        vl.addLayout(btn_row)

        self.quit_btn = QPushButton('⏻  Quit Chameleon')
        self.quit_btn.setFixedHeight(26)
        self.quit_btn.setStyleSheet(
            f'background-color: {PANEL2}; border: 1px solid {BORDER}; '
            f'color: {DIM}; font-size: 9px; border-radius: 4px;')
        self.quit_btn.clicked.connect(self._quit)
        vl.addWidget(self.quit_btn)

        vl.addStretch()

        self._on_mode_changed()

        # Wrap in scroll area and return outer container
        scroll.setWidget(panel)
        outer_vl.addWidget(scroll)
        return outer

    def _make_right_panel(self):
        panel = QWidget()
        panel.setStyleSheet(f'background-color: {BG};')
        vl = self._vbox(panel)
        vl.setContentsMargins(8, 8, 8, 8)
        vl.setSpacing(6)

        lbl = QLabel('LIVE PREVIEW')
        lbl.setObjectName('section_lbl')
        vl.addWidget(lbl)

        # Image row
        img_row = QWidget()
        ir_hl = self._hbox(img_row)
        ir_hl.setSpacing(8)

        orig_col = QWidget()
        oc_vl = self._vbox(orig_col)
        oc_vl.setSpacing(2)
        orig_lbl = QLabel('ORIGINAL')
        orig_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        orig_lbl.setStyleSheet(f'color: {DIM}; font-size: 9px; font-weight: bold;')
        self.canvas_orig = ImageCanvas(title_color=DIM)
        oc_vl.addWidget(orig_lbl)
        oc_vl.addWidget(self.canvas_orig)

        norm_col = QWidget()
        nc_vl = self._vbox(norm_col)
        nc_vl.setSpacing(2)
        norm_lbl = QLabel('NORMALISED')
        norm_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        norm_lbl.setStyleSheet(f'color: {DIM}; font-size: 9px; font-weight: bold;')
        self.canvas_norm = ImageCanvas(title_color=ACCENT)
        nc_vl.addWidget(norm_lbl)
        nc_vl.addWidget(self.canvas_norm)

        ir_hl.addWidget(orig_col)
        ir_hl.addWidget(norm_col)
        vl.addWidget(img_row, stretch=3)

        # Histogram row
        hist_row = QWidget()
        hr_hl = self._hbox(hist_row)
        hr_hl.setSpacing(8)

        self.hist_orig = HistCanvas(title='Original Histogram')
        self.hist_norm = HistCanvas(title='Normalised Histogram')
        hr_hl.addWidget(self.hist_orig)
        hr_hl.addWidget(self.hist_norm)
        vl.addWidget(hist_row, stretch=1)

        return panel

    # ── Mode descriptions ─────────────────────────────────────────────
    MODE_DESCRIPTIONS = [
        'Match each image\'s full RGB distribution to a single chosen reference slide. Best when you have a high-quality reference with ideal staining.',
        'Build a theoretical mean histogram across all images, then match every image to that population average. No reference image needed.',
        'Transfer LAB color statistics (mean + std per channel) from a reference image to each source. More conservative than histogram matching; lower artifact risk.',
        'Compute mean LAB statistics across the entire batch to build a bias-free synthetic reference, then apply Reinhard normalization to all images.',
    ]

    def _on_mode_changed(self, *_):
        mode = self.mode_group.checkedId()
        if mode < 1:
            return
        self.mode_desc.setText(self.MODE_DESCRIPTIONS[mode - 1])
        needs_ref = mode in (1, 3)
        self.ref_group.setEnabled(needs_ref)
        self.ref_field.setEnabled(needs_ref)

    # ── File handling ─────────────────────────────────────────────────
    def _browse_input(self):
        folder = QFileDialog.getExistingDirectory(self, 'Select Input Folder')
        if folder:
            self.input_field.setText(folder)
            self._load_folder(folder)

    def _browse_ref(self):
        path, _ = QFileDialog.getOpenFileName(
            self, 'Select Reference Image', '',
            'Image Files (*.tif *.tiff *.jpg *.jpeg *.bmp)')
        if path:
            self.ref_field.setText(path)

    def _browse_output(self):
        folder = QFileDialog.getExistingDirectory(self, 'Select Output Folder')
        if folder:
            self.output_field.setText(folder)

    def _load_folder(self, folder):
        files = find_images(folder)
        if not files:
            QMessageBox.warning(self, 'No Images',
                f'No supported images found in:\n{folder}\n\n'
                'Supported formats: TIF, TIFF, JPG, JPEG, BMP')
            return
        self._image_paths = files
        self.file_list.clear()
        for f in files:
            self.file_list.addItem(Path(f).name)
        self.count_lbl.setText(f'{len(files)} image(s) loaded')
        self._set_status(f'Loaded {len(files)} images.', SUCCESS)

    def _reload_files(self):
        folder = self.input_field.text()
        if folder and os.path.isdir(folder):
            self._load_folder(folder)

    def _clear_files(self):
        self._image_paths = []
        self.file_list.clear()
        self.count_lbl.setText('0 images loaded')
        self.canvas_orig.clear()
        self.canvas_norm.clear()
        self.hist_orig.clear()
        self.hist_norm.clear()
        self._set_status('File list cleared.', DIM)

    # ── Inspector ─────────────────────────────────────────────────────
    def _open_inspector(self):
        if not self._image_paths:
            QMessageBox.warning(self, 'No Images', 'Please load images first.')
            return
        self._inspector = InspectorWindow(
            self._image_paths, self.ref_field.text(), parent=self)
        self._inspector.method_chosen.connect(self._apply_inspector_method)
        self._inspector.show()

    def _apply_inspector_method(self, mode: int):
        self.mode_radios[mode - 1].setChecked(True)
        self._set_status(
            f'Method set to: {self.mode_radios[mode - 1].text()}', SUCCESS)

    # ── Run / Cancel ──────────────────────────────────────────────────
    def _validate(self) -> bool:
        if not self._image_paths:
            QMessageBox.warning(self, 'No Images', 'Please load images first.')
            return False
        mode = self.mode_group.checkedId()
        if mode in (1, 3) and not (
                self.ref_field.text() and
                Path(self.ref_field.text()).is_file()):
            QMessageBox.warning(self, 'Missing Reference',
                                'Please select a valid reference image.')
            return False
        if not self.output_field.text():
            QMessageBox.warning(self, 'No Output Folder',
                                'Please specify an output folder.')
            return False
        os.makedirs(self.output_field.text(), exist_ok=True)
        return True

    def _run(self):
        if not self._validate():
            return

        mode = self.mode_group.checkedId()
        self._worker = NormWorker(
            mode          = mode,
            image_paths   = self._image_paths,
            output_dir    = self.output_field.text(),
            fmt           = self.fmt_combo.currentText(),
            save_log      = self.log_check.isChecked(),
            ref_path      = self.ref_field.text() or None,
            n_workers     = int(self.workers_combo.currentText()),
        )
        self._worker.signals.progress.connect(self._on_progress)
        self._worker.signals.finished.connect(self._on_finished)
        self._worker.signals.error.connect(self._on_error)

        self.run_btn.setEnabled(False)
        self.cancel_btn.setEnabled(True)
        self.progress_bar.setValue(0)
        self._worker.start()

    def _cancel(self):
        if self._worker:
            self._worker.cancel()
            self._set_status('Cancelling…', WARNING)

    def _on_progress(self, current, total, msg):
        self.progress_bar.setMaximum(total)
        self.progress_bar.setValue(current)
        self.progress_lbl.setText(msg)
        self._set_status(msg, ACCENT)

    def _on_finished(self, msg):
        self.run_btn.setEnabled(True)
        self.cancel_btn.setEnabled(False)
        self.progress_bar.setValue(self.progress_bar.maximum())
        self.progress_lbl.setText('Complete')
        self._set_status(msg, SUCCESS)
        QMessageBox.information(self, 'Complete', msg)

    def _on_error(self, msg):
        self.run_btn.setEnabled(True)
        self.cancel_btn.setEnabled(False)
        self._set_status(f'Error: {msg}', DANGER)
        QMessageBox.critical(self, 'Error', msg)

    def _quit(self):
        self.close()

    def closeEvent(self, event):
        """Cancel any running worker and exit cleanly so terminal prompt returns."""
        if self._worker and self._worker.isRunning():
            self._worker.cancel()
            self._worker.wait(2000)  # wait up to 2s for clean shutdown
        QApplication.quit()
        event.accept()

    def _set_status(self, msg: str, color: str = DIM):
        self.status_lbl.setText(msg)
        self.status_lbl.setStyleSheet(
            f'color: {color}; font-size: 10px; padding: 0 10px;')

    # ── Layout helpers ─────────────────────────────────────────────────
    @staticmethod
    def _vbox(widget=None):
        from PyQt6.QtWidgets import QVBoxLayout
        layout = QVBoxLayout()
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(4)
        if widget:
            widget.setLayout(layout)
        return layout

    @staticmethod
    def _hbox(widget=None):
        from PyQt6.QtWidgets import QHBoxLayout
        layout = QHBoxLayout()
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(6)
        if widget:
            widget.setLayout(layout)
        return layout


# ── Entry point ────────────────────────────────────────────────────────────

def main():
    app = QApplication(sys.argv)
    app.setApplicationName('Chameleon')
    app.setStyle('Fusion')
    window = MainWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == '__main__':
    main()
