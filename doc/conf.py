
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
html_title = u'Querying with Combinators'
author = u'Prometheus Research LLC'
copyright = u'2015, Prometheus Research LLC'
version = '2015'
release = '2015'
html_static_path = ['_static']
templates_path = ['_templates']
exclude_patterns = ['_build']
pygments_style = 'sphinx'
latex_elements = {
    'preamble': r'''
%\usepackage[doublespacing]{setspace}
\DeclareUnicodeCharacter{22EE}{$\vdots$}
''',
    'pointsize': '12pt',
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

if 'slides_in_html' in tags:
    slides_in_html = False

def setup(app):
    app.add_config_value('slides_in_html', False, 'html')
    app.connect('html-collect-pages', _build_slides)

from sphinx.builders.html import StandaloneHTMLBuilder
original_script_files = StandaloneHTMLBuilder.script_files[:]
original_css_files = StandaloneHTMLBuilder.css_files[:]

def _build_slides(app):
    if app.builder.format != 'html' or not app.config.slides_in_html:
        return []
    current_script_files = StandaloneHTMLBuilder.script_files
    current_css_files = StandaloneHTMLBuilder.css_files
    StandaloneHTMLBuilder.script_files = original_script_files
    StandaloneHTMLBuilder.css_files = original_css_files
    from sphinx.application import Sphinx
    slides_dir = os.path.join(app.outdir, '_slides')
    slides_app = Sphinx(
            app.srcdir, app.confdir, slides_dir, app.doctreedir, 'slides',
            status=None, warning=app._warning,
            warningiserror=app.warningiserror,
            tags=['slides_in_html'])
    slides_app.build()
    StandaloneHTMLBuilder.script_files = current_script_files
    StandaloneHTMLBuilder.css_files = current_css_files
    return []

