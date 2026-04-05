function styleConfusionChartBlack(h)
%% styleConfusionChartBlack — black text; white axes; zero-count cells white (confusionchart default is black).

    if nargin < 1 || ~isgraphics(h)
        return
    end
    blk = [0 0 0];
    try
        set(h, 'ZeroColor', [1 1 1]);
    catch
    end
    try
        par = h.Parent;
        if isgraphics(par)
            if isprop(par, 'Color')
                par.Color = 'w';
            end
            if strcmpi(par.Type, 'axes') && isprop(par, 'GridColor')
                par.GridColor = [0.85 0.85 0.85];
            end
        end
    catch
    end
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
