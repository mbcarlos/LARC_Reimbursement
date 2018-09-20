from pathlib import Path

date = raw_input("What is the date used to the name the folder? ")
#mypath = "S:\LARC\event_study_graphs\%s" %(date)
mypath = "/Users/marisacarlos/Dropbox/Cornell/Research/Projects/LARC_Reimbursement/graphs/event_studies/"+date+"/"

prefixes = ["natality","lbw"]
suffixes = ["total","unmarried","teen","hsorless"]
tex_file_lines =[ r'''\documentclass[11pt]{article}''',r'''\usepackage{geometry}''',r'''\geometry{letterpaper}''',r'''\usepackage{graphicx}''',
                 r'''\usepackage{float}''',r'''\pagestyle{empty}''',r'''\begin{document}''']

ldq_or_fdq = "ldq"


if Path(r'''%slarc_utilization_quarterly_ES.pdf''' %(mypath)).is_file():
    tex_file_lines.append(r'''\begin{figure}[H]''')
    tex_file_lines.append(r'''    \includegraphics[width=\textwidth]{larc_utilization_quarterly_ES.pdf}''' %())
    tex_file_lines.append(r'''\end{figure}''')

for prefix in prefixes:
    for suffix in suffixes:
        if Path(r'''%s%s_%s_%s_C2_quarter_ES.pdf'''%(mypath,prefix,suffix,ldq_or_fdq)).is_file() or Path(r'''%s%s_%s_%s_C1_quarter_ES.pdf'''%(mypath,prefix,suffix,ldq_or_fdq)).is_file():
            
            tex_file_lines.append(r'''\begin{figure}[H]''')
            
            if Path(r'''%s%s_%s_%s_C2_quarter_ES.pdf'''%(mypath,prefix,suffix,ldq_or_fdq)).is_file():
                tex_file_lines.append(r'''    \includegraphics[width=\textwidth]{%s_%s_%s_C2_quarter_ES.pdf}''' %(prefix,suffix,ldq_or_fdq))
            else:
                tex_file_lines.append(r'''no quarterly 2nd child graph for %s_%s''' %(prefix,suffix))
                tex_file_lines.append(r''' \\ ''')
                tex_file_lines.append(r''' \\ ''')
                tex_file_lines.append(r''' \\ ''')
            if Path(r'''%s%s_%s_%s_C1_quarter_ES.pdf'''%(mypath,prefix,suffix,ldq_or_fdq)).is_file():
                tex_file_lines.append(r'''    \includegraphics[width=\textwidth]{%s_%s_%s_C1_quarter_ES.pdf}''' %(prefix,suffix,ldq_or_fdq))
            else:
                tex_file_lines.append(r'''no quarterly 1st child/unknown graph for %s %s''' %(prefix,suffix))
            tex_file_lines.append(r'''\end{figure}''')
            #tex_file_lines.append(r'''\newpage''')
        # NOT DOING MONTHLY GRAPHS ANYMORE
        # if Path(r'''%s%s_%s_C2_month_ES.pdf'''%(mypath,prefix,suffix)).is_file() or Path(r'''%s%s_%s_C1_month_ES.pdf'''%(mypath,prefix,suffix)).is_file():
        #     tex_file_lines.append(r'''\begin{figure}[H]''')
        #     if Path(r'''%s%s_%s_C2_month_ES.pdf'''%(mypath,prefix,suffix)).is_file():
        #         tex_file_lines.append(r'''    \includegraphics[width=\textwidth]{%s_%s_C2_month_ES.pdf}''' %(prefix,suffix))
        #     else:
        #         tex_file_lines.append(r'''no monthly 2nd child graph for %s_%s''' %(prefix,suffix))
        #         tex_file_lines.append(r''' \\ ''')
        #         tex_file_lines.append(r''' \\ ''')
        #         tex_file_lines.append(r''' \\ ''')
        #     if Path(r'''%s%s_%s_C1_month_ES.pdf'''%(mypath,prefix,suffix)).is_file():
        #         tex_file_lines.append(r'''    \includegraphics[width=\textwidth]{%s_%s_C1_month_ES.pdf}''' %(prefix,suffix))
        #     else:
        #         tex_file_lines.append(r'''no monthly 1st child/unknown graph for %s %s''' %(prefix,suffix))
        # 
        #     tex_file_lines.append(r'''\end{figure}''')
        #     tex_file_lines.append(r'''\newpage''')
    
            
print("%sevent_study_graphs_%s.tex" %(mypath, date))
with open("%sevent_study_graphs_%s.tex" %(mypath, date), 'w') as tex_file:
    for i in range(0,len(tex_file_lines)):
        tex_file.write(tex_file_lines[i] + '\n')
    tex_file.write(r'''\end{document}''' + '\n')