
import os

on_rtd = os.environ.get('READTHEDOCS', None) == 'True'
if not on_rtd:
    html_theme = 'sphinx_rtd_theme'

extensions = [
    'sphinx.ext.mathjax',
    'sphinx.ext.graphviz',
    'hieroglyph',
]
master_doc = 'index'
default_role = 'obj'
project = u'rbt-proto'
html_title = u'Query Language for Functional Data Model'
author = u'Prometheus Research LLC'
copyright = u'2015, Prometheus Research LLC'
version = '2015'
release = '2015'
html_static_path = ['_static']
templates_path = ['_templates']
exclude_patterns = ['_build']
pygments_style = 'sphinx'
latex_elements = {
    'preamble': '',
}
latex_documents = [
    (master_doc, 'rbt-proto.tex', html_title, author, 'howto', True),
]
slide_theme = 'slides2'
slide_theme_options = {
    'custom_css': 'slides.css',
}
autoslides = False
slides_in_html = True

def setup(app):
    app.add_config_value('slides_in_html', False, 'html')
    app.connect('html-collect-pages', _build_slides)

def _build_slides(app):
    if app.builder.format != 'html' or not app.config.slides_in_html:
        return []
    from sphinx.application import Sphinx
    slides_dir = os.path.join(app.outdir, '_slides')
    slides_app = Sphinx(
            app.srcdir, app.confdir, slides_dir, app.doctreedir,
            'slides', { 'slides_in_html': False },
            status=None, warning=app._warning,
            warningiserror=app.warningiserror)
    slides_app.build()
    return []

