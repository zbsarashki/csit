
.. raw:: latex

    \clearpage

.. raw:: html

    <script type="text/javascript">

        function getDocHeight(doc) {
            doc = doc || document;
            var body = doc.body, html = doc.documentElement;
            var height = Math.max( body.scrollHeight, body.offsetHeight,
                html.clientHeight, html.scrollHeight, html.offsetHeight );
            return height;
        }

        function setIframeHeight(id) {
            var ifrm = document.getElementById(id);
            var doc = ifrm.contentDocument? ifrm.contentDocument:
                ifrm.contentWindow.document;
            ifrm.style.visibility = 'hidden';
            ifrm.style.height = "10px"; // reset to minimal height ...
            // IE opt. for bing/msn needs a bit added or scrollbar appears
            ifrm.style.height = getDocHeight( doc ) + 4 + "px";
            ifrm.style.visibility = 'visible';
        }

    </script>

3n-hsw-x520
~~~~~~~~~~~

64b-1t1c-base_and_features
--------------------------

.. raw:: html

    <center>
    <iframe id="ifrm01" onload="setIframeHeight(this.id)" width="700" frameborder="0" scrolling="no" src="../../_static/vpp/memif-3n-hsw-x520-64b-1t1c-base_and_features-ndr-lat.html"></iframe>
    <p><br></p>
    </center>

.. raw:: latex

    \begin{figure}[H]
        \centering
            \graphicspath{{../_build/_static/vpp/}}
            \includegraphics[clip, trim=0cm 0cm 5cm 0cm, width=0.70\textwidth]{memif-3n-hsw-x520-64b-1t1c-base_and_features-ndr-lat}
            \label{fig:memif-3n-hsw-x520-64b-1t1c-base_and_features-ndr-lat}
    \end{figure}

.. raw:: latex

    \clearpage

64b-2t2c-base_and_features
--------------------------

.. raw:: html

    <center>
    <iframe id="ifrm02" onload="setIframeHeight(this.id)" width="700" frameborder="0" scrolling="no" src="../../_static/vpp/memif-3n-hsw-x520-64b-2t2c-base_and_features-ndr-lat.html"></iframe>
    <p><br></p>
    </center>

.. raw:: latex

    \begin{figure}[H]
        \centering
            \graphicspath{{../_build/_static/vpp/}}
            \includegraphics[clip, trim=0cm 0cm 5cm 0cm, width=0.70\textwidth]{memif-3n-hsw-x520-64b-2t2c-base_and_features-ndr-lat}
            \label{fig:memif-3n-hsw-x520-64b-2t2c-base_and_features-ndr-lat}
    \end{figure}
