import os



with open("blueprint.md", "w") as out:

    for filename in os.listdir("gf_output"):

          pola = filename.replace(".txt", "")

          with open("gf_output/" + filename) as f:

                      urls = f.read()

                      jumlah = urls.count("\n")

          out.write("## " + pola.upper() + " (" + str(jumlah) + ")\n")

          out.write(urls)

          out.write("\n")
