from pathlib import Path
from shutil import copyfile

date = raw_input("What is the date used to the name the folder? ")
#date = "19 Sep 2018"
mypath = "/Users/marisacarlos/Dropbox/Cornell/Research/Projects/LARC_Reimbursement/graphs/exploratory_graphs/"+date+"/"
orig_event_study_path = "/Users/marisacarlos/Dropbox/Cornell/Research/Projects/LARC_Reimbursement/graphs/event_studies/"+date+"/"


state_drop_list_birth_data = ["CA","CO","DE","DC","GA","ID","IL","IN","IA","LA","MD","MT","NM","NY","OK","RI","SC","TX","WA","WY"]
state_drop_list_larc_data = ["CT","FL","ID","LA","MA","ME","OK","RI","VT","WV"]

tex_file_lines =[ r'''\documentclass[11pt]{article}''',r'''\usepackage{geometry}''',r'''\geometry{letterpaper}''',r'''\usepackage{graphicx}''',
                 r'''\usepackage{float}''',r'''\pagestyle{empty}''',r'''\begin{document}''',r''' \begin{center}''']

prefixes = ["natality","lbw"]
suffixes = ["total","unmarried","teen","hsorless"]

ldq_or_fdq = "ldq"

if Path(r'''%slarc_utilization_quarterly_ES.pdf'''%(orig_event_study_path)).is_file():
    copyfile(orig_event_study_path+"larc_utilization_quarterly_ES.pdf", mypath+"larc_utilization_quarterly_ES.pdf")
    tex_file_lines.append(r'''\textbf{EVENT STUDY INCLUDING ALL STATES:}''')
    tex_file_lines.append(r'''    \includegraphics[width=.8\textwidth]{larc_utilization_quarterly_ES.pdf}''')
    tex_file_lines.append(r'''\newpage''')
    tex_file_lines.append(r'''\textbf{EVENT STUDIES DROPPING INDIVIDUAL STATES:}''')
    for state in state_drop_list_larc_data:
        if Path(r'''%slarc_utilization_quarterly_ES_no%s.pdf'''%(mypath,state)).is_file():
            tex_file_lines.append(r'''    \includegraphics[width=.8\textwidth]{larc_utilization_quarterly_ES_no%s.pdf}''' %(state))
    
tex_file_lines.append(r'''\newpage''')

for prefix in prefixes:
    for suffix in suffixes:
        if Path(r'''%s%s_%s_%s_C2_quarter_ES.pdf'''%(orig_event_study_path,prefix,suffix,ldq_or_fdq)).is_file():
            copyfile(orig_event_study_path+prefix+"_"+suffix+"_"+ldq_or_fdq+"_C2_quarter_ES.pdf",mypath+prefix+"_"+suffix+"_"+ldq_or_fdq+"_C2_quarter_ES.pdf")
            tex_file_lines.append(r'''\textbf{EVENT STUDY INCLUDING ALL STATES:}''')
            tex_file_lines.append(r'''    \includegraphics[width=.8\textwidth]{%s_%s_%s_C2_quarter_ES.pdf}''' %(prefix,suffix,ldq_or_fdq))
            tex_file_lines.append(r'''\newpage''')
            tex_file_lines.append(r'''\textbf{EVENT STUDIES DROPPING INDIVIDUAL STATES:}''')
            for state in state_drop_list_birth_data:
                if Path(r'''%s%s_%s_%s_C2_quarter_ES_no%s.pdf'''%(mypath,prefix,suffix,ldq_or_fdq,state)).is_file():
                    tex_file_lines.append(r'''    \includegraphics[width=.8\textwidth]{%s_%s_%s_C2_quarter_ES_no%s.pdf}''' %(prefix,suffix,ldq_or_fdq,state))
                    
            tex_file_lines.append(r'''\newpage''')
            
        
print("%sES_graphs_dropstates_%s.tex" %(mypath, date))
with open(("%sES_graphs_dropstates_%s.tex" %(mypath, date)), 'w') as tex_file:
    for i in range(0,len(tex_file_lines)):
        tex_file.write(tex_file_lines[i] + '\n')
    tex_file.write(r'''\end{center}''' + '\n')
    tex_file.write(r'''\end{document}''' + '\n')