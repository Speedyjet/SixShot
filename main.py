# main.py
from crewai import Task, Crew, Process
from langchain_ollama import ChatOllama
from agents import create_architect, create_developer

architect_llm = ChatOllama(model="qwen3:8b", base_url="http://localhost:11434", temperature=0.0)
developer_llm = ChatOllama(model="qwen3.5:4b", base_url="http://localhost:11434", temperature=0.0)

architect = create_architect(architect_llm)
developer = create_developer(developer_llm)

# Свидание 1: Архитектор
plan_task = Task(
    description="Спецификация: CAN ID 0x1A4, 2 байта, little-endian, скорость. Напиши .h файл.",
    expected_output="Только C++ код .h файла, без markdown блоков и текста.",
    agent=architect
)

# Свидание 2: Разработчик
# Он получает контекст ТОЛЬКО из результата plan_task, история чата обрезается.
code_task = Task(
    description="Реализуй .cpp для следующего заголовочного файла: {{plan_task.output}}",
    expected_output="Только C++ код .cpp файла, без markdown блоков и текста.",
    agent=developer,
    context=[plan_task] # Жесткая привязка входа ко выходу предыдущей задачи
)

crew = Crew(
    agents=[architect, developer],
    tasks=[plan_task, code_task],
    process=Process.sequential,
    memory=False, # КРИТИЧНО: Отключает долгосрочную память и болтовню между агентами
    verbose=True
)

if __name__ == "__main__":
    result = crew.kickoff()
    print(result)