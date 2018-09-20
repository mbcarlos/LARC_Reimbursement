from pathlib import Path

#date = raw_input("What is the date used to the name the folder? ")
date = "19 Sep 2018"
mypath = "/Users/marisacarlos/Dropbox/Cornell/Research/Projects/LARC_Reimbursement/graphs/exploratory_graphs/"+date+"/"


state_drop_list = ["CA","CO","DE","DC","GA","ID","IL","IN","IA","LA","MD","MT","NM","NY","OK","RI","SC","TX","WA","WY"]

tex_file_lines =[ r'''\documentclass[11pt]{article}''',r'''\usepackage{geometry}''',r'''\geometry{letterpaper}''',r'''\usepackage{graphicx}''',
                 r'''\usepackage{float}''',r'''\pagestyle{empty}''',r'''\begin{document}''',r''' \begin{center}''']

prefixes = ["natality","lbw"]
suffixes = ["total","unmarried","teen","hsorless"]

ldq_or_fdq = "ldq"


for prefix in prefixes:
    for suffix in suffixes:
        if Path(r'''%s%s_%s_%s_C2_quarter_ES.pdf'''%(mypath,prefix,suffix,ldq_or_fdq)).is_file():
            tex_file_lines.append(r'''\textbf{EVENT STUDY INCLUDING ALL STATES:}''')
            tex_file_lines.append(r'''    \includegraphics[width=\textwidth]{%s_%s_%s_C2_quarter_ES.pdf}''' %(prefix,suffix,ldq_or_fdq))
            tex_file_lines.append(r'''\newpage''')
            tex_file_lines.append(r'''\textbf{EVENT STUDIES DROPPING INDIVIDUAL STATES:}''')
            for state in state_drop_list:
                if Path(r'''%s%s_%s_%s_C2_quarter_ES_no%s.pdf'''%(mypath,prefix,suffix,ldq_or_fdq,state)).is_file():
                    tex_file_lines.append(r'''    \includegraphics[width=\textwidth]{%s_%s_%s_C2_quarter_ES_no%s.pdf}''' %(prefix,suffix,ldq_or_fdq,state))
                    
            tex_file_lines.append(r'''\newpage''')
            
        
print("%sES_graphs_dropstates_%s.tex" %(mypath, date))
with open(("%sES_graphs_dropstates_%s.tex" %(mypath, date)), 'w') as tex_file:
    for i in range(0,len(tex_file_lines)):
        tex_file.write(tex_file_lines[i] + '\n')
    tex_file.write(r'''\end{center}''' + '\n')
    tex_file.write(r'''\end{document}''' + '\n')