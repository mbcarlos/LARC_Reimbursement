from pathlib import Path

#date = 10062017
date = raw_input("What is the date used to the name the folder? ")
#mypath = "S:\LARC\event_study_graphs\%s" %(date)
mypath = "/Users/marisacarlos/Dropbox/Cornell/Research/Projects/LARC_Reimbursement/graphs/event_studies/"+date+"/"

prefixes = ["natality","lbw"]
suffixes = ["total","unmarried","teen","hsorless"]
tex_file_lines =[ r'''\documentclass[11pt]{article}''',r'''\usepackage{geometry}''',r'''\geometry{letterpaper}''',r'''\usepackage{graphicx}''',
                 r'''\usepackage{float}''',r'''\pagestyle{empty}''',r'''\begin{document}''']

ldq_or_fdq = "ldq"
#ldq_or_fdq = raw_input("fdq or ldq (lowercase)? ")

#tex_file_lines.append(r'''\begin{figure}[H]''')
#tex_file_lines.append(r'''    \includegraphics[width=\textwidth]{larc_util_%s_quarter_ES.pdf}''' %(ldq_or_fdq))
#caption_unedited = "larc_util_%s" %(ldq_or_fdq)
#caption_edited = caption_unedited.replace("_"," ")
#tex_file_lines.append(r''' \caption{%s}''' %(caption_edited))
#tex_file_lines.append(r'''\end{figure}''')
#tex_file_lines.append(r'''\newpage''')
tex_file_lines.append('This page intentionally blank. Compare the following pages two pages at a time. First page is for any birth order, second page \
     is for second or greater birth order. The two page comparison will allow to compare across  birth order for the same birth type\
     (total births, premature, low birthweight) and same population (all, black, hispanic, teen, unmarried).')

for prefix in prefixes:
    for suffix in suffixes:
        ## Any birth order:
        # First make sure month graph exists (not all datasets for month, e.g. hsorless):
        if Path(r'''%s%s_%s_month_ES.pdf''' %(mypath, prefix, suffix)).is_file():
            tex_file_lines.append(r'''\begin{figure}[H]''')
            tex_file_lines.append(r'''    \includegraphics[width=\textwidth]{%s_%s_month_ES.pdf}''' %(prefix, suffix))
            tex_file_lines.append(r'''    \includegraphics[width=\textwidth]{%s_%s_%s_quarter_ES.pdf}''' %(prefix, suffix, ldq_or_fdq))
            caption_unedited = "%s_%s_month (top) and %s_%s_quarter (bottom), all birth orders" %(prefix, suffix, prefix, suffix)
            caption_edited = caption_unedited.replace("_"," ")
            tex_file_lines.append(r'''    \caption{%s}''' %(caption_edited))
            tex_file_lines.append(r'''\end{figure}''')
        else:
            tex_file_lines.append(r'''    \textbf{(No month graph) \\}''')
            tex_file_lines.append(r''' \\ ''')
            tex_file_lines.append(r''' \\ ''')
        ## Second+ birth order:
        ## First make sure the file exists (not all second order graphs made):
        if Path(r'''%s%s_%s_C2_month_ES.pdf''' %(mypath, prefix, suffix)).is_file() or Path(r'''%s%s_%s_%s_C2_quarter_ES.pdf''' %(mypath, prefix, suffix, ldq_or_fdq)).is_file():
            caption_unedited = ""
            tex_file_lines.append(r'''\begin{figure}[H]''')
            if Path(r'''%s%s_%s_C2_month_ES.pdf''' %(mypath, prefix, suffix)).is_file():
                tex_file_lines.append(r'''    \includegraphics[width=\textwidth]{%s_%s_C2_month_ES.pdf}''' %(prefix, suffix))
                caption_unedited = "%s %s %s month (top)" %(caption_unedited, prefix, suffix)
            else:
                tex_file_lines.append(r'''    \textbf{(No month graph because of small cells) \\}''')
                tex_file_lines.append(r''' \\ ''')
                tex_file_lines.append(r''' \\ ''')
            if Path(r'''%s%s_%s_%s_C2_quarter_ES.pdf''' %(mypath, prefix, suffix, ldq_or_fdq)).is_file():
                tex_file_lines.append(r'''    \includegraphics[width=\textwidth]{%s_%s_%s_C2_quarter_ES.pdf}''' %(prefix, suffix, ldq_or_fdq))
                caption_unedited = "%s %s %s quarter (bottom)" %(caption_unedited, prefix, suffix)
            else:
                tex_file_lines.append(r'''    \textbf{(No quarter graph because of small cells) \\}''')
                tex_file_lines.append(r''' \\ ''')
                tex_file_lines.append(r''' \\ ''')
            caption_edited = caption_unedited.replace("_"," ")
            tex_file_lines.append(r'''    \caption{%s, second plus birth order}''' %(caption_edited))
            tex_file_lines.append(r'''\end{figure}''')
        else:
            tex_file_lines.append(r'''\newpage''')
            tex_file_lines.append('No month or quarter graphs due to small cells.')
            
        
#for item in tex_file_lines:
    #print(item) 

print("%s/event_study_graphs_%s.tex" %(mypath, date))
with open("%s/event_study_graphs_%s.tex" %(mypath, date), 'w') as tex_file:
    for i in range(0,len(tex_file_lines)):
        tex_file.write(tex_file_lines[i] + '\n')
    tex_file.write(r'''\end{document}''' + '\n')