function styleConfusionChartBlack(h)
%% styleConfusionChartBlack — confusion matrix cell/summary/title text to black (not default gray).

    if nargin < 1 || ~isgraphics(h)
        return
    end
    blk = [0 0 0];
    pn = {'CellLabelColor', 'TitleFontColor', 'SummaryFontColor', 'FontColor', ...
        'XLabelColor', 'YLabelColor', 'XLabelFontColor', 'YLabelFontColor'};
    for k = 1:numel(pn)
        if isprop(h, pn{k})
            try
                h.(pn{k}) = blk;
            catch
            end
        end
    end
end
